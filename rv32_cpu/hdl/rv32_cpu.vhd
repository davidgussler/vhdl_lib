-- #############################################################################
-- #  -<< RISC-V CPU >>-
-- # ===========================================================================
-- # Copyright 2022, David Gusser
-- # ===========================================================================
-- # File     : rv32_cpu.vhd
-- # Author   : David Gussler - davidnguss@gmail.com 
-- # Language : VHDL '08
-- # ===========================================================================
-- # 
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gen_utils_pkg.all;
use work.rv32_pkg.all;

entity rv32_cpu is
    generic (
        HART_ID    : std_logic_vector(31 downto 0) := x"0000_0000";
        RESET_ADDR : std_logic_vector(31 downto 0) := x"0000_0000";
        TRAP_ADDR  : std_logic_vector(31 downto 0) := x"1C09_0000";
        MTIME_ADDR : std_logic_Vector(31 downto 0) := x"0C09_0000"
    );
    port (
        -- Clock & Reset
        i_clk       : in  std_logic; 
        i_rst       : in  std_logic; 
        
        -- Instruction  Interface 
        o_iren      : out std_logic;
        o_iaddr     : out std_logic_vector(31 downto 0);
        o_ifence    : out std_logic;
        i_irdat     : in  std_logic_vector(31 downto 0);
        i_istall    : in  std_logic;
        i_ierror    : in  std_logic;

        -- Data Interface 
        o_dren      : out std_logic;
        o_dwen      : out std_logic;
        o_dben      : out std_logic_vector(3 downto 0); -- byte enable 
        o_daddr     : out std_logic_vector(31 downto 0);
        o_dfence    : out std_logic;
        o_dwdat     : out std_logic_vector(31 downto 0);
        i_drdat     : in  std_logic_vector(31 downto 0);
        i_dstall    : in  std_logic;
        i_derror    : in  std_logic;

        -- Interrupts
        i_ms_irq   : in  std_logic; 
        i_me_irq   : in  std_logic; 
        i_mt_irq   : in  std_logic; 

        -- Other
        o_sleep     : out std_logic;
        o_debug     : out std_logic;
        i_db_halt   : in  std_logic

    );
end entity;


architecture rtl of rv32_cpu is

   -- Pipeline phase signals
   -- Signals associated with a phase can either come from the pipeline register
   -- before that phase or be set combinationally within that pahse.
   signal fet : fet_t; 
   signal dec : dec_t; 
   signal exe : exe_t;
   signal mem : mem_t;  
   signal wrb : wrb_t;

begin
    -- =========================================================================
    -- Fetch Stage =============================================================
    -- =========================================================================
    
    -- Handle Interrupts & Exceptions ------------------------------------------
    -- -------------------------------------------------------------------------
    -- Delay the interrupt pending bits by 1 so we can detect a rising edge 
    -- NOTE: The mem.csr.mip bits are tied directly to the i_mX_irq input signals
    process (i_clk)
    begin
        if (rising_edge(i_clk)) then
            if (i_rst) then
                fet.dly_mip_msi <= '0';
                fet.dly_mip_mti <= '0';
                fet.dly_mip_mei <= '0';
            else
                fet.dly_mip_msi <= mem.csr.mip(MSI);
                fet.dly_mip_mti <= mem.csr.mip(MTI);
                fet.dly_mip_mei <= mem.csr.mip(MEI);
            end if;
        end if;
    end process;

    -- Set the PC to the trap address for an interrupt if:
    -- 1.  Interrupts are enabled globally 
    -- 2.  The specific interrupt is enabled
    -- 3a. The specific interrupt has gone from not pending to pending -OR-
    -- 3b. The specific interrupt is still pending after returning from the last 
    --     interrupt service routine (but in most cases this probably shouldnt
    --     happen because we would expect the ISR to do something to clear the 
    --     pending interrupt)
    -- NOTE: This does not handle nested interrupts. For example, if mt_irq_pulse goes high, 
    -- the flow jumps to the trap addr, the isr starts, and then mt_irq_pulse goes high again, 
    -- the the flow will jump to the trap addr again, even if we haven't gotten an mret
    -- instruciton. In practice this shouldn't be an issue (assuming the NVIC external to the 
    -- cpu is designed well)
    fet.ms_irq_pulse <= (mem.csr.mip(MSI) and (not fet.dly_mip_msi or dec.mret)) and mem.csr.mie(MSI) and mem.csr.mstatus(MIE); 
    fet.mt_irq_pulse <= (mem.csr.mip(MTI) and (not fet.dly_mip_mti or dec.mret)) and mem.csr.mie(MTI) and mem.csr.mstatus(MIE); 
    fet.me_irq_pulse <= (mem.csr.mip(MEI) and (not fet.dly_mip_mei or dec.mret)) and mem.csr.mie(MEI) and mem.csr.mstatus(MIE); 

    
    -- All Exceptions and Interrupts
    fet.trap_taken <= ms_irq_pulse or mt_irq_pulse or me_irq_pulse or 
            mem.load_ma_adr_excpt or mem.load_access_excpt or 
            mem.store_ma_adr_excpt or mem.store_access_excpt or 
            dec.illegal_instr or dec.ecall_except or dec.ebreak_except or 
            fet.instr_adr_ma_excpt or fet.instr_access_excpt; 



    -- Program Counter ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    sp_pc : process (i_clk) 
    begin
        if (rising_edge(i_clk)) then
            if (i_rst) then
                fet.pc <= RESET_ADDR(31 downto 2) & b"00";
            else 
                if (not haz.pc_enable) then
                    fet.pc <= fet.pc; 
                elsif (dec.mret) then
                    fet.pc <= mem.csr.epc;
                elsif (fet.trap_taken) then -- Must have higher priority than branch 
                    fet.pc <= TRAP_ADDR(31 downto 2) & b"00";
                elsif (dec.br_taken) then
                    fet.pc <= dec.brt_adr; 
                else 
                    fet.pc <= std_logic_vector(unsigned(fet.pc) + 4);  
                end if;
            end if;
        end if; 
    end process;
    
    fet.instr_adr_ma_excpt <= fet.pc(0) or fet.pc(1);
    fet.instr_access_excpt <= i_ierror; 

    o_iren    <= '1'; 
    o_iaddr   <= fet.pc;
    dec.instr <= i_irdat;
    o_ifence  <= '0'; -- TODO: 


    -- =========================================================================
    -- Fetch/Decode Registers ==================================================
    -- =========================================================================
    sp_fet_dec_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst or haz.dec_flush) then
            
            elsif (haz.dec_enable) then
                dec.pc           <= fet.pc; 
                dec.ms_irq_pulse <= fet.ms_irq_pulse;
                dec.mt_irq_pulse <= fet.mt_irq_pulse;
                dec.me_irq_pulse <= fet.me_irq_pulse;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Decode Stage ============================================================
    -- =========================================================================
    dec.opcode   <= dec.instr(RANGE_OPCODE);
    dec.rs1_adr  <= dec.instr(RANGE_RS1);
    dec.rs2_adr  <= dec.instr(RANGE_RS2);
    dec.rdst_adr <= dec.instr(RANGE_RD);
    dec.funct3   <= dec.instr(RANGE_FUNCT3);
    dec.funct7   <= dec.instr(RANGE_FUNCT7);


    -- Register File 
    -- On a write, reads should output what was written 
    -- What happens when a register is read and written in the same clock
    -- cycle? We assume that the write is in the first half of the clock cycle and the read
    -- is in the second half, so the read delivers what is written.
    -- Thats from the patterson book. I'm not going to assme that. I'll have to stall by one 
    -- cycle if this is the case. 
    -- Sync Writes
    sp_regfile_write : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if wrb.reg_wr = '1' and wrb.rdst_adr /= b"00000" then
                dec.regfile(to_integer(unsigned(wrb.rdst_adr))) <= wrb.rdst_dat; 
            end if; 
        end if;
    end process;

    -- Async Reads. Needs to be async so I can handle branch resolution in dec stage.
    ap_regfile_read : process (all)
    begin
        if dec.rs1_adr = "00000" then
            dec.rs1_dat <= (others=>'0');
        else
            dec.rs1_dat <= dec.regfile(to_integer(unsigned(dec.rs1_adr)));
        end if;

        if dec.rs2_adr = "00000" then
            dec.rs2_dat <= (others=>'0');
        else
            dec.rs2_dat <= dec.regfile(to_integer(unsigned(dec.rs2_adr)));
        end if;
    end process;


    
    -- Opcode Decoding
    u_control : entity work.rv32_control
    port map(
       i_opcode => dec.opcode,
       o_ctrl   => dec.ctrl
    );
 

    -- Construct the 32-bit signed immediate
    -- NOTE: could add another decode stage to process this since it happens after opcode decoder
    ap_imm32 : process (all) 
    begin
        case (dec.ctrl.imm_type) is
            when (STYPE) => 
                dec.imm32(31 downto 12) <= (others=>dec.instr(31));
                dec.imm32(11 downto 5)  <= dec.instr(RANGE_IMM_S_11_5);
                dec.imm32(4 downto 0)   <= dec.instr(RANGE_IMM_S_4_0);

            when (BTYPE) => 
                dec.imm32(31 downto 13) <= (others=>dec.instr(31));
                dec.imm32(12)           <= dec.instr(RANGE_IMM_B_12);
                dec.imm32(11)           <= dec.instr(RANGE_IMM_B_11);
                dec.imm32(10 downto 5)  <= dec.instr(RANGE_IMM_B_10_5);
                dec.imm32(4 downto 1)   <= dec.instr(RANGE_IMM_B_4_1);
                dec.imm32(0)            <= '0';

            when (UTYPE) => 
                dec.imm32(31 downto 12) <= dec.instr(RANGE_IMM_U);
                dec.imm32(11 downto 0)  <= X"000";

            when (JTYPE) => 
                dec.imm32(31 downto 21) <= (others=>dec.instr(31));
                dec.imm32(20)           <= dec.instr(RANGE_IMM_J_20);
                dec.imm32(19 downto 12) <= dec.instr(RANGE_IMM_J_19_12);
                dec.imm32(11)           <= dec.instr(RANGE_IMM_J_11);
                dec.imm32(10 downto 1)  <= dec.instr(RANGE_IMM_J_10_1);
                dec.imm32(0)            <= '0';
            
            when others  => -- ITYPE
                dec.imm32(31 downto 12) <= (others=>dec.instr(31));
                dec.imm32(11 downto 0)  <= dec.instr(RANGE_IMM_I);

       end case; 
    end process; 


    -- determine if a branch was taken and calculate the target address for 
    -- branches and jumps. Jumps (JAL, JALR) will always be taken 
    -- Adding the extra hardware to resolve branch in this stage rather than
    -- alu stage to save a stall cycle on mispredicted branches. Using a simple
    -- predict not taken scheme. 
    ap_branch_resolution : process(all)
        variable v_brt_adr : std_logic_vector(31 downto 0);
    begin

        dec.br_eq  <= '1' when dec.rs1_dat = dec.rs2_dat else '0'; 
        dec.br_ltu <= '1' when unsigned(dec.rs1_dat) < unsigned(dec.rs2_dat) else '0'; 
        dec.br_lt  <= '1' when signed(dec.rs1_dat) < signed(dec.rs2_dat) else '0'; 

        case (dec.funct3) is 
            when F3_BEQ  => dec.branch <=     dec.br_eq; 
            when F3_BNE  => dec.branch <= not dec.br_eq; 
            when F3_BLT  => dec.branch <=     dec.br_lt;
            when F3_BGE  => dec.branch <= not dec.br_lt;
            when F3_BLTU => dec.branch <=     dec.br_ltu;
            when F3_BGEU => dec.branch <= not dec.br_ltu;
            when others  => dec.branch <= '0';
        end case; 
      

        -- Control signal indicating that a branch, jal, or jalr has been taken
        dec.br_taken <= dec.ctrl.jal or dec.ctrl.jalr or (dec.ctrl.branch and dec.branch);

        -- Branch, jal, or jalr target address
        if dec.ctrl.jalr then
            v_brt_adr := std_logic_vector(signed(dec.imm32) + signed(dec.rs1_dat)); 
            v_brt_adr := v_brt_adr(31 downto 1) & '0';
        else
            v_brt_adr :=  std_logic_vector(signed(dec.imm32) + signed(dec.pc)); 
        end if;   

        dec.brt_adr <= v_brt_adr; 

    end process;


    -- System Instructions -----------------------------------------------------
    -- -------------------------------------------------------------------------
    ap_system : process (all)
    begin
        dec.ecall_excpt <= '0'; 
        dec.ecall_excpt <= '0'; 
        dec.mret        <= '0';
        dec.wfi         <= '0';
        dec.csr_access  <= '0'; 

        if (dec.ctrl.sys) then
            if (dec.funct3 = F3_ENV) then
                case (dec.imm32(11 downto 0)) is 
                    when F12_ECALL  => dec.ecall_excpt <= '1'; 
                    when F12_EBREAK => dec.ebreak_excpt <= '1'; 
                    when F12_MRET   => dec.mret        <= '1';
                    when F12_WFI    => dec.wfi         <= '1';
                    when others     => null;
                end case; 
            else 
                dec.csr_access <= '1'; 
            end if;
        end if; 
    end process;


    -- =========================================================================
    -- Decode/Execute Registers ================================================
    -- =========================================================================
    sp_dec_exe_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst or haz.exe_flush) then
            

            elsif (haz.exe_enable) then
                exe.ctrl     <= dec.ctrl; 
                exe.rs1_dat  <= dec.rs1_dat;
                exe.rs2_dat  <= dec.rs2_dat;
                exe.rs1_adr  <= dec.rs1_adr;
                exe.rs2_adr  <= dec.rs2_adr;
                exe.rdst_adr <= dec.rdst_adr;
                exe.funct3   <= dec.funct3;
                exe.pc       <= dec.pc; 
                exe.imm32    <= dec.imm32; 

            end if; 
        end if;
    end process;

    -- =========================================================================
    -- Execute Stage ===========================================================
    -- =========================================================================
    -- Generate the aluop
    ap_alu_ctrl : process (all)
    begin
        case (exe.ctrl.alu_ctrl) is 
            when ALUCTRL_ADD  => exe.aluop <= ALUOP_ADD;  
            when ALUCTRL_ALU  => exe.aluop <= exe.funct7(5) & exe.funct3; 
            when others       => exe.aluop <= (others=>'-'); 
        end case; 
    end process;

    -- Select the alu operands
    ap_alu_sel : process (all) 
    begin 
        case (exe.alua_sel) is 
            when ALUA_RS1     => exe.alu_a <= exe.rs1_dat; 
            when ALUA_PC      => exe.alu_a <= exe.pc; 
            when ALUA_ZERO    => exe.alu_a <= (others=>'0'); 
            when others       => exe.alu_a <= (others=>'-'); 
        end case; 

        case (exe.alub_sel) is 
            when ALUB_RS2   => exe.alu_b <= exe.rs2_dat; 
            when ALUB_IMM32 => exe.alu_b <= exe.imm32; 
            when others     => exe.alu_b <= (others=>'-'); 
        end case;
    end process; 
 

    -- Integer alu
    ap_alu : process (all)
    begin
        case exe.aluop is
            when ALUOP_ADD  => exe.alu_rslt <= std_logic_vector(signed(exe.alu_a) + signed(exe.alu_b)); 
            when ALUOP_SUB  => exe.alu_rslt <= std_logic_vector(signed(exe.alu_a) - signed(exe.alu_b)); 
            when ALUOP_SLL  => exe.alu_rslt <= std_logic_vector(shift_left(unsigned(exe.alu_a), to_integer(unsigned(exe.alu_b(4 downto 0)))));    
            when ALUOP_SLT  => exe.alu_rslt <= x"0000_0001" when (signed(exe.alu_a) < signed(exe.alu_b))  else x"0000_0000"; 
            when ALUOP_SLTU => exe.alu_rslt <= x"0000_0001" when (unsigned(exe.alu_a) < unsigned(exe.alu_b)) else x"0000_0000"; 
            when ALUOP_XOR  => exe.alu_rslt <= exe.alu_a xor exe.alu_b; 
            when ALUOP_SRL  => exe.alu_rslt <= std_logic_vector(shift_right(unsigned(exe.alu_a), to_integer(unsigned(exe.alu_b(4 downto 0)))));    
            when ALUOP_SRA  => exe.alu_rslt <= std_logic_vector(shift_right(signed(exe.alu_a), to_integer(unsigned(exe.alu_b(4 downto 0)))));
            when ALUOP_OR   => exe.alu_rslt <= exe.alu_a or exe.alu_b; 
            when ALUOP_AND  => exe.alu_rslt <= exe.alu_a or exe.alu_b; 
            when others     => exe.alu_rslt <= (others=>'-');
        end case; 
    end process; 


    
    -- =========================================================================
    -- Execute/Memory Registers ================================================
    -- =========================================================================
    sp_exe_mem_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst or haz.mem_flush) then
            
            elsif haz.mem_enable then
                mem.ctrl     <= exe.ctrl; 
                mem.alu_rslt <= exe.alu_rslt;
                mem.rs2_dat  <= exe.rs2_dat;
                mem.rs2_adr  <= exe.rs2_adr;
                mem.funct3   <= exe.funct3; 
                mem.pc       <= exe.pc; 
                mem.rdst_adr <= exe.rdst_adr; 
            end if; 
        end if;
    end process;


    -- =========================================================================
    -- Memory Stage ============================================================
    -- =========================================================================
    o_dren <= mem.ctrl.mem_rd;  
    o_dwen <= mem.ctrl.mem_wr;       
    o_daddr <= mem.alu_rslt; 
    o_dwdat <= mem.rs2_dat; 
    
    mem.load_ma_adr_excpt <= mem.ctrl.mem_rd and (o_daddr(1) or o_daddr(0));
    mem.load_access_excpt <= mem.ctrl.mem_rd and i_derror;
    mem.store_ma_adr_excpt <= mem.ctrl.mem_wr and (o_daddr(1) or o_daddr(0));
    mem.store_access_excpt <= mem.ctrl.mem_wr and i_derror;

    o_dfence <= '0'; -- TODO:  

    -- Memory Access -----------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Loads
    ap_data_load : process (all)
    begin
        case mem.funct3 is 
            when F3_LB  => 
                wrb.memrd_dat(31 downto 8)  <= (others=>i_drdat(8));
                wrb.memrd_dat(7 downto 0)   <= i_drdat(7 downto 0);

            when F3_LH  =>
                wrb.memrd_dat(31 downto 16) <= (others=>i_drdat(16));
                wrb.memrd_dat(15 downto 0)  <= i_drdat(15 downto 0);

            when F3_LW  => 
                wrb.memrd_dat(31 downto 0)  <= i_drdat;

            when F3_LBU =>
                wrb.memrd_dat(31 downto 8)  <= (others=>'0');
                wrb.memrd_dat(7 downto 0)   <= i_drdat(7 downto 0);

            when F3_LHU => 
                wrb.memrd_dat(31 downto 16) <= (others=>'0');
                wrb.memrd_dat(15 downto 0)  <= i_drdat(15 downto 0);

            when others => 
                wrb.memrd_dat(31 downto 0)  <= (others=>'-');

        end case; 
    end process;

    -- Stores
    ap_data_store : process (all)
    begin
        case mem.funct3 is
            when F3_SB  => o_dben <= b"0001";
            when F3_SH  => o_dben <= b"0011";   
            when F3_SW  => o_dben <= b"1111"; 
            when others => o_dben <= b"----";
        end case;
    end process;



    -- CSR Access --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Generate the csr write data (for CSR instr SW writes)
    ap_csr_wdata : process (all)
    begin

        case mem.funct3 is 
            when F3_CSRRW =>  
                mem.csr_wdata <= mem.rs1_dat;

            when F3_CSRRS =>
                mem.csr_wdata <= mem.rs1_dat or mem.csr_rdata;

            when F3_CSRRC =>
                mem.csr_wdata <= not mem.rs1_dat and mem.csr_rdata;

            when F3_CSRRWI =>  
                mem.csr_wdata(31 downto 5) <= (others=>'0');
                mem.csr_wdata(4 downto 0)  <= mem.rs1_adr;

            when F3_CSRRSI =>
                mem.csr_wdata(31 downto 5) <= mem.csr_rdata(31 downto 5);
                mem.csr_wdata(4 downto 0)  <= mem.rs1_adr or mem.csr_rdata(4 downto 0);

            when F3_CSRRCI =>
                mem.csr_wdata(31 downto 5) <= (others=>'0');
                mem.csr_wdata(4 downto 0)  <= not mem.rs1_adr and mem.csr_rdata(4 downto 0);

            when others    => 
                mem.csr_wdata <= (others=>'-');
        end case; 
    end process;

    -- Was there a trap? 
    mem.any_trap <= mem.ms_irq or mem.mt_irq or mem.me_irq or 
                    mem.load_ma_adr_excpt or mem.load_access_excpt or 
                    mem.store_ma_adr_excpt or mem.store_access_excpt or 
                    mem.illegal_instr or mem.ecall_except or mem.ebreak_except or 
                    mem.instr_adr_ma_excpt or mem.instr_access_excpt; 

    -- mepc (1:0) must always be forced to 0
    mem.csr.mepc(1 downto 0)  <= b"00";

    -- Writes
    sp_csr_wr : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                mem.csr.mstatus <= (others=>'-');
                -- TODO: reset values 

            -- Software writes by CSR instructions
            else 
                if (mem.csr_access) then
                    case mem.imm32(11 downto 0) is
                        when CSR_FFLAGS  =>
                        when CSR_FRM     =>
                        when CSR_FCSR    =>

                        when CSR_MSTATUS =>
                            mem.csr.mstatus(MIE)  <= mem.csr_wdata(MIE); 
                        
                        when CSR_MIE =>
                            mem.csr.mie(MSI) <= mem.csr_wdata(MSI); 
                            mem.csr.mie(MTI) <= mem.csr_wdata(MTI); 
                            mem.csr.mie(MEI) <= mem.csr_wdata(MEI); 
                        
                        when CSR_MSTATUS

                        when CSR_MEPC

                        when CSR_MSTATUS
                        
                        when CSR_MCYCLE =>
                            mem.csr.mcycle   <= mem.csr_wdata; 
                            
                        when CSR_MINSTRET =>
                            mem.csr.minstret <= mem.csr_wdata; 

                        when CSR_MCOUNTINHIBIT => 
                            mem.csr.mcountinhibit(CY) <= mem.csr_wdata(CY);
                            mem.csr.mcountinhibit(IR) <= mem.csr_wdata(IR);

                        when others =>
                            null;
                    end case;   
                end if;  

                -- Hardware writes by CPU
                -- These take priority over a software write if they happen on the
                -- same cycle
                
                

                --mem.csr.fflags      <= ; TODO: add these with FP extension 
                --mem.csr.frm         <= ; TODO: add these with FP extension 
                --mem.csr.fcsr        <= ; TODO: add these with FP extension 
                --mem.csr.mstatus(FS) <= ; TODO: add these with FP extension 
                --mem.csr.mstatus(SD) <= ; TODO: add these with FP extension
                
                mem.csr.mip(MSI) <= i_ms_irq;
                mem.csr.mip(MTI) <= i_me_irq;
                mem.csr.mip(MEI) <= i_mt_irq;

                mem.csr.mtime    <= 
                mem.csr.mcycle   <= 
                mem.csr.minstret <=

                if (mem.any_trap) then
                    mem.csr.mstatus(MPIE) <= mem.csr.mstatus(MIE);
                end if;   

                -- Set epc and mcause during a trap
                -- NOTE: SW is expected to increment the epc to the next instruction 
                -- for an ecall/ebreak. If SW doesnt do this, then we'll get caught 
                -- in an ecall / irq handler / mret ... loop 
                -- I wanted to set the epc to pc+4 for ecall/ebreak, but doing so 
                -- would violate the RISCV specification
                if (mem.ms_irq_pulse) then 
                    mem.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    mem.csr.mcause(INTR)      <= '1'; 
                    mem.csr.mcause(CODE)      <= TRAP_MSI_IRQ; --3
                elsif (mem.mt_irq_pulse) then
                    mem.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    mem.csr.mcause(INTR)      <= '1'; 
                    mem.csr.mcause(CODE)      <= TRAP_MTI_IRQ; --7
                elsif (mem.me_irq_pulse) then
                    mem.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    mem.csr.mcause(INTR)      <= '1'; 
                    mem.csr.mcause(CODE)      <= TRAP_MEI_IRQ; --11
                elsif (mem.instr_adr_ma_excpt) then
                    mem.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    mem.csr.mcause(INTR)      <= '0'; 
                    mem.csr.mcause(CODE)      <= TRAP_IMA; --0
                elsif (mem.instr_access_excpt) then
                    mem.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    mem.csr.mcause(INTR)      <= '0'; 
                    mem.csr.mcause(CODE)      <= TRAP_IACC; --1
                elsif (mem.illegal_instr_excpt) then
                    mem.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    mem.csr.mcause(INTR)      <= '0'; 
                    mem.csr.mcause(CODE)      <= TRAP_ILL_INTR; --2
                elsif (mem.ebreak_excpt) then
                    mem.csr.mepc(31 downto 2) <= mem.pc4(31 downto 2);
                    mem.csr.mcause(INTR)      <= '0'; 
                    mem.csr.mcause(CODE)      <= TRAP_EBREAK; --3
                elsif (mem.load_adr_ma_excpt) then
                    mem.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    mem.csr.mcause(INTR)      <= '0'; 
                    mem.csr.mcause(CODE)      <= TRAP_LMA; --4
                elsif (mem.load_access_excpt) then
                    mem.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    mem.csr.mcause(INTR)      <= '0'; 
                    mem.csr.mcause(CODE)      <= TRAP_LACC; --5
                elsif (mem.store_adr_ma_excpt) then
                    mem.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    mem.csr.mcause(INTR)      <= '0'; 
                    mem.csr.mcause(CODE)      <= TRAP_SMA; --6
                elsif (mem.store_access_excpt) then
                    mem.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    mem.csr.mcause(INTR)      <= '0'; 
                    mem.csr.mcause(CODE)      <= TRAP_SACC; --7
                elsif (mem.ecall_except) then
                    mem.csr.mepc(31 downto 2) <= mem.pc4(31 downto 2);
                    mem.csr.mcause(INTR)      <= '0'; 
                    mem.csr.mcause(CODE)      <= TRAP_MECALL; --11
                end if; 
            end if; 
        end if;
    end process;


    -- Reads
    ap_csr_rd : process(all)
    begin 

        mem.csr_rdata <= (others=>'0'); -- default

        if (mem.csr_access) then
            case mem.imm32(11 downto 0) is
                
                --when CSR_FFLAGS  => mem.csr_rdata <= mem.csr.fflags; TODO: add these with FP extension
                --when CSR_FRM     => mem.csr_rdata <= mem.csr.frm   ; TODO: add these with FP extension
                --when CSR_FCSR    => mem.csr_rdata <= mem.csr.fcsr  ; TODO: add these with FP extension

                when CSR_TIME =>
                    mem.csr_rdata <= mem.csr.mtime; 
            
                when CSR_MHARTID =>
                    mem.csr_rdata  <= HART_ID;

                when CSR_MSTATUS =>
                    mem.csr_rdata(MIE)  <= mem.csr.mstatus(MIE) ;
                    mem.csr_rdata(MPIE) <= mem.csr.mstatus(MPIE);
                    --mem.csr_rdata(FS)   <= mem.csr.mstatus(FS)  ; TODO: add these with FP extension
                    --mem.csr_rdata(SD)   <= mem.csr.mstatus(SD)  ; TODO: add these with FP extension
                
                when CSR_MTVEC =>
                    mem.csr_rdata(MODE) <= b"00"; -- Direct mode - All exceptions set PC to BASE
                    mem.csr_rdata(BASE) <= TRAP_ADDR(31 downto 2); 

                when CSR_MIE =>
                    mem.csr_rdata(MSI) <= mem.csr.mie(MSI); 
                    mem.csr_rdata(MTI) <= mem.csr.mie(MTI); 
                    mem.csr_rdata(MEI) <= mem.csr.mie(MEI); 

                when CSR_MIP =>
                    mem.csr_rdata(MSI) <= mem.csr.mip(MSI); 
                    mem.csr_rdata(MTI) <= mem.csr.mip(MTI); 
                    mem.csr_rdata(MEI) <= mem.csr.mip(MEI); 

                when CSR_MCYCLE | CSR_CYCLE =>
                    mem.csr_rdata <= mem.csr.mcycle; 

                when CSR_MINSTRET | CSR_INSTRET =>
                    mem.csr_rdata <= mem.csr.minstret; 
                
                when CSR_MCOUNTINHIBIT => 
                    mem.csr_rdata(CY) <= mem.csr.mcountinhibit(CY); 
                    mem.csr_rdata(IR) <= mem.csr.mcountinhibit(IR);

                when CSR_MEPC =>
                    mem.csr_rdata(1 downto 0)  <= b"00";
                    mem.csr_rdata(31 downto 2) <= mem.csr.mepc(31 downto 2);

                when CSR_MCAUSE =>
                    mem.csr_rdata(INTR) => mem.csr.mcause(INTR);
                    mem.csr_rdata(CODE) => mem.csr.mcause(CODE);

                when others =>
                    null;
            end case;
        end if;
    end process; 


    -- =========================================================================
    -- Memory/Writeback Registers ==============================================
    -- =========================================================================
    sp_mem_wrb_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst or haz.wrb_flush) then
            

            elsif (haz.wrb_enable) then
                wrb.ctrl      <= mem.ctrl; 
                wrb.alu_rslt  <= mem.alu_rslt;
                wrb.pc4       <= std_logic_vector(unsigned(mem.pc) + 4);
                wrb.rdst_adr  <= mem.rdst_adr;
                wrb.csr_rdata <= mem.csr_rdata; 
            end if; 
        end if;
    end process;


    -- =========================================================================
    -- Writeback Stage =========================================================
    -- =========================================================================
    ap_wrb_mux : process (all) 
    begin
        case (wrb.ctrl.wrb_sel) is 
            when WRB_SEL_ALU => wrb.rdst_dat <= wrb.alu_rslt;
            when WRB_SEL_MEM => wrb.rdst_dat <= wrb.memrd_dat;
            when WRB_SEL_CSR => wrb.rdst_dat <= wrb.csr_rdata;
            when WRB_SEL_PC4 => wrb.rdst_dat <= wrb.pc4; 
            when others      => wrb.rdst_dat <= (others=>'-');
        end case; 
    end process; 



    -- TODO: execptions & wfi, CSRs, hazards (stalls) & forwarding 
    -- TODO: once I have the cpu implemented and tested, experiment with different
    -- architecture decisions to try to speed things up (for example synchronous
    -- register file reads / branch resolution in exe)



    -- =========================================================================
    -- Hazard Unit =============================================================
    -- =========================================================================
    -- Detects and resolves pipeline hazards by forwarding where possible and 
    -- stalling otherwise
    
    -- Forwarding --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- TODO: think about forwarding due to not having a write thru register file 
    -- I actually think I may have solved this by forwarding from wrb to decode???
    -- Needs to be thought about deeply.. Pretty sure its good, but dbl check my thinking in the morning

    -- Stages closest to target stage take priority because they have the most recent value 
    -- All of these are "data hazards"
    ap_forwarding : process (all)
    begin
        -- Forwarding to decode stage
        -- should only need to forward to decode stage if it is a branch or jalr instruction 
        -- TODO: add logic to check for branch in decode stage (I think )
        -- Can I forward regardless of it being a branch? I beleive I can. This shouldnt hurt 
        -- anything 
        -- RS1
        --if    (exe.ctrl.reg_wr = '1' and exe.rdst_adr /= b"00000" and exe.rdst_adr = dec.rs1_adr) then
        --    haz.dec_rs1_fw_sel <= EXE_FW;
        if (mem.ctrl.reg_wr = '1' and mem.rdst_adr /= b"00000" and mem.rdst_adr = dec.rs1_adr) then
            haz.dec_rs1_fw_sel <= MEM_FW;
        elsif (wrb.ctrl.reg_wr = '1' and wrb.rdst_adr /= b"00000" and wrb.rdst_adr = dec.rs1_adr) then
            haz.dec_rs1_fw_sel <= WRB_FW;
        else 
            haz.dec_rs1_fw_sel <= NO_FW;
        end if; 
        -- RS2
        --if    (exe.ctrl.reg_wr = '1' and exe.rdst_adr /= b"00000" and exe.rdst_adr = dec.rs2_adr) then
        --    haz.dec_rs2_fw_sel <= EXE_FW;
        if (mem.ctrl.reg_wr = '1' and mem.rdst_adr /= b"00000" and mem.rdst_adr = dec.rs2_adr) then
            haz.dec_rs2_fw_sel <= MEM_FW;
        elsif (wrb.ctrl.reg_wr = '1' and wrb.rdst_adr /= b"00000" and wrb.rdst_adr = dec.rs2_adr) then
            haz.dec_rs2_fw_sel <= WRB_FW;
        else 
            haz.dec_rs2_fw_sel <= NO_FW;
        end if; 

        -- TODO: can I get rid of some of this???
        -- -- Forwarding to execute stage
        -- -- RS1
        if    (mem.ctrl.reg_wr = '1' and mem.rdst_adr /= b"00000" and mem.rdst_adr = exe.rs1_adr) then
            haz.exe_rs1_fw_sel <= MEM_FW;
        elsif (wrb.ctrl.reg_wr = '1' and wrb.rdst_adr /= b"00000" and wrb.rdst_adr = exe.rs1_adr) then
            haz.exe_rs1_fw_sel <= WRB_FW;
        else 
            haz.exe_rs1_fw_sel <= NO_FW;
        end if; 
        -- RS2
        if    (mem.ctrl.reg_wr = '1' and mem.rdst_adr /= b"00000" and mem.rdst_adr = exe.rs2_adr) then
            haz.exe_rs2_fw_sel <= MEM_FW;
        elsif (wrb.ctrl.reg_wr = '1' and wrb.rdst_adr /= b"00000" and wrb.rdst_adr = exe.rs2_adr) then
            haz.exe_rs2_fw_sel <= WRB_FW;
        else 
            haz.exe_rs2_fw_sel <= NO_FW;
        end if; 

        -- Forwarding to memory stage
        -- Should only need to forward if there is a load (ie mem.ctrl.mem_rd), but not checking this 
        -- and forwarding regardless doesnt hurt anything. might as well leave this check out 
        -- to save a small ammount of logic
        -- RS1 is not needed in the memory stage
        -- RS2
        if    (wrb.ctrl.reg_wr = '1' and wrb.rdst_adr /= b"00000" and wrb.rdst_adr = mem.rs2_adr) then
            haz.mem_rs2_fw_sel <= WRB_FW;
        else 
            haz.mem_rs2_fw_sel <= NO_FW;
        end if; 

    end process;



    -- Stalling & Flushing -----------------------------------------------------
    -- -------------------------------------------------------------------------

    -- Data Hazards ------------------------------------------------------------
    -- Load Hazard - if load is in exe while dependent instruction is in dec, 
    -- stall the pipe.
    -- This is a "data hazard" that is not solvable by pure forwarding
    -- Dont need to check mem.ctrl.reg_wr because we know that is already 1 if mem.ctrl.mem_rd is 1
    haz.ld_hazard <= '1' when  exe.ctrl.mem_rd = '1' 
                      and  exe.rdst_adr /= b"00000"
                      and (exe.rdst_adr = dec.rs1_adr or exe.rdst_adr = dec.rs2_adr) 
                    else '0'; 


    -- Data Hazards (due to branches being calculated in the dec phase)
    -- if branch is in ID while ld is in EX or MEM wait till ld gets to WB
    haz.br_ld_mem_hazard <= '1' when dec.ctrl.branch = '1' 
                             and mem.mem_rd = '1' 
                             and mem.rdst_adr /= "00000" 
                             and (mem.rdst_adr = dec.rs1_adr 
                              or mem.rdst_adr = dec.rs2_adr) 
                    else '0'; 

    haz.jalr_ld_mem_hazard <= '1' when dec.ctrl.jalr = '1' 
                               and mem.mem_rd = '1' 
                               and mem.rdst_adr /= "00000" 
                               and mem.rdst_adr = dec.rs1_adr 
                    else '0'; 

    -- if branch is in ID while add,etc is in EX, wait till add,etc is in MEM
    haz.br_hazard <= '1' when dec.ctrl.branch = '1' 
                      and exe.reg_wr = '1' 
                      and exe.rdst_adr /= "00000" 
                      and (exe.rdst_adr = dec.rs1_adr 
                       or exe.rdst_adr = dec.rs2_adr) 
                    else '0';

    haz.jalr_hazard <= '1' when dec.ctrl.jalr = '1' 
                        and exe.reg_wr = '1' 
                        and exe.rdst_adr /= "00000" 
                        and (exe.rdst_adr = dec.rs1_adr) 
                    else '0';  

    -- If an mret instr follows an epc csr write, then we need to stall until the 
    -- epc is updated with the latest value 
    haz.mret_hazard <= '1' when dec.mret = '1' 
                            and exe.csr_access = '1' 
                            and mem.rs1_adr /= b"00000"
                            and exe.imm32(11 downto 0) = CSR_MEPC
                        else '0'; 

    ap_flush_stall : process (all)
    begin
        -- Defaults 
        haz.pc_enable  <= '1'; 
        haz.dec_enable <= '1';
        haz.exe_enable <= '1';
        haz.mem_enable <= '1';
        haz.wrb_enable <= '1';
        haz.dec_flush  <= '0';
        haz.exe_flush  <= '0'; 
        haz.mem_flush  <= '0';
        haz.wrb_flush  <= '0';


        -- Control Hazards -----------------------------------------------------
        
        -- kill the instruction that caused the trap after it has written its trap information during the memory stage
        -- This way, any illegal value that comes from an illegal instruction does not get writen back 
        if (mem.any_trap) then 
            haz.wrb_flush <= '1'; 
        end if; 

        -- Memory stage exceptions 
        if (mem.load_ma_adr_excpt or mem.load_access_excpt or
                mem.store_ma_adr_excpt or mem.store_access_excpt) then
            haz.dec_flush <= '1';
            haz.exe_flush <= '1'; 
            haz.mem_flush <= '1';

        -- Decode stage exceptions (and mret) 
        elsif (dec.illegal_instr or dec.ecall_except or dec.ebreak_except or dec.mret) then
            haz.dec_flush <= '1';
        
        -- Fetch stage exceptions dont need to remove any unnecessarially fetched instructions

        -- Branch Mispredicts 
        elsif (dec.br_taken) then -- kill the mispredicted instruction
            haz.exe_flush <= '1'; -- is this right? should it be dec_flush? 
        
        end if; 


        -- Wait on Memory ------------------------------------------------------
        if (i_dstall) then -- pause the pipe while waiting on dmem stall
            haz.pc_enable  <= '0'; 
            haz.dec_enable <= '0';
            haz.exe_enable <= '0'; 
            haz.mem_enable <= '0';
            haz.wrb_flush  <= '1';

        elsif (i_istall) then -- pause the pipeline while waiting on the imem stall 
            haz.pc_enable  <= '0'; 
            haz.dec_flush  <= '1'; 



        -- Data Hazards --------------------------------------------------------
        elsif (haz.ld_hazard or haz.br_hazard or haz.jalr_hazard or haz.mret_hazard) then -- stall at dec, bubble at exe
            haz.pc_enable  <= '0'; 
            haz.dec_enable <= '0';
            haz.exe_flush  <= '1'; 

        elsif (haz.br_ld_mem_hazard or haz.jalr_ld_mem_hazard) then -- stall at dec, bubble at mem
            haz.pc_enable  <= '0'; 
            haz.dec_enable <= '0';
            haz.mem_flush  <= '1';
        end if; 
    end process;












    -- =========================================================================
    -- Performance Counters ====================================================
    -- =========================================================================
    







end architecture;










