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
        TRAP_ADDR  : std_logic_vector(31 downto 0) := x"1C09_0000"
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
        i_msi_irq   : in  std_logic; 
        i_mei_irq   : in  std_logic; 
        i_mti_irq   : in  std_logic; 

        -- Other
        o_sleep     : out std_logic;
        o_debug     : out std_logic;
        i_db_halt   : in  std_logic;
        i_mtime     : in  std_logic_vector(31 downto 0)

    );
end entity;


architecture rtl of rv32_cpu is
   -- pipeline phases
   -- signals associated with a phase can either come from the pipeline register
   -- before that phase or be set combinationally within that pahse
   signal fet : fet_t; 
   signal dec : dec_t; 
   signal exe : exe_t;
   signal mem : mem_t;  
   signal wrb : wrb_t;

begin
    -- =========================================================================
    -- Fetch ===================================================================
    -- =========================================================================
    
    -- PC
    sp_pc : process (i_clk) 
    begin
        if (rising_edge(i_clk)) then
            if i_rst then
                fet.pc <= RESET_ADDR;
            else 
                if haz.pc_stall then
                    fet.pc <= fet.pc; 
                elsif trap then
                    fet.pc <= TRAP_ADDR(31 downto 2) & b"00";
                elsif dec.br_taken then
                    fet.pc <= dec.brt_adr; 
                else 
                    fet.pc <= fet.pc4;
                end if;
            end if;
        end if; 
    end process;
    
    fet.pc4 <= std_logic_vector(unsigned(fet.pc) + 4);  
    
    fet.instr_adr_ma_excpt <= fet.pc(0) or fet.pc(1);
    dec.instr_access_excpt <= i_ierror; 

    o_iren    <= '1'; 
    o_iaddr   <= fet.pc;
    dec.instr <= i_irdat;
    o_ifence  <= '0'; -- TODO: 
    -- i_istall; 


    -- Fetch => Decode registers
    sp_fet_dec_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
            
            else 
                dec.pc  <= fet.pc; 
                dec.pc4 <= fet.pc4;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Decode ==================================================================
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



    -- Decode => Execute registers
    sp_dec_exe_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
            
            else 
                exe.ctrl     <= dec.ctrl; 
                exe.rs1_dat  <= dec.rs1_dat;
                exe.rs2_dat  <= dec.rs2_dat;
                exe.funct3   <= dec.funct3;
                exe.pc4      <= dec.pc4; 
                ece.rdst_adr <= dec.rdst_adr;
                exe.imm32    <= dec.imm32; 
            end if;
        end if;
    end process;




    -- =========================================================================
    -- Execute =================================================================
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


    -- CSRs --------------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Generate the csr write data 
    ap_csr_wdata : process (all)
    begin

        case exe.funct3 is 
            when F3_CSRRW =>  
                exe.csr_wdata <= exe.rs1_dat;

            when F3_CSRRS =>
                exe.csr_wdata <= exe.rs1_dat or exe.csr_rdata;

            when F3_CSRRC =>
                exe.csr_wdata <= not exe.rs1_dat and exe.csr_rdata;

            when F3_CSRRWI =>  
                exe.csr_wdata(31 downto 5) <= (others=>'0');
                exe.csr_wdata(4 downto 0)  <= exe.rs1_adr;

            when F3_CSRRSI =>
                exe.csr_wdata(31 downto 5) <= exe.csr_rdata(31 downto 5);
                exe.csr_wdata(4 downto 0)  <= exe.rs1_adr or exe.csr_rdata(4 downto 0);

            when F3_CSRRCI =>
                exe.csr_wdata(31 downto 5) <= (others=>'0');
                exe.csr_wdata(4 downto 0)  <= not exe.rs1_adr and exe.csr_rdata(4 downto 0);

            when others   => 
                exe.csr_wdata <= (others=>'-');
        end case; 
    end process;


    -- Write Access 
    sp_csr_wr : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst then
                exe.csr.mstatus <= (others=>'-');

            -- Software writes by CSR instructions
            elsif exe.ctrl.sys then
                case exe.imm32(11 downto 0) is
                    when CSR_FFLAGS  =>
                    when CSR_FRM     =>
                    when CSR_FCSR    =>

                    when CSR_MSTATUS =>
                        exe.csr.mstatus(MIE)  <= exe.csr_wdata(MIE); 
                    
                    when CSR_MIE =>
                        exe.csr.mie(MSI) <= exe.csr_wdata(MSI); 
                        exe.csr.mie(MTI) <= exe.csr_wdata(MTI); 
                        exe.csr.mie(MEI) <= exe.csr_wdata(MEI); 
                    
                    when CSR_MCYCLE =>
                        exe.csr.mcycle   <= exe.csr_wdata; 
                        
                    when CSR_MINSTRET =>
                        exe.csr.minstret <= exe.csr_wdata; 

                    when CSR_MCOUNTINHIBIT => 
                        exe.csr.mcountinhibit(CY) <= exe.csr_wdata(CY);
                        exe.csr.mcountinhibit(IR) <= exe.csr_wdata(IR);

                    when others =>
                        null;
                end case;    

            -- Hardware writes by CPU
            else 
                
                exe.csr.mtime <= ; 

                --exe.csr.fflags      <= ; TODO: add these with FP extension 
                --exe.csr.frm         <= ; TODO: add these with FP extension 
                --exe.csr.fcsr        <= ; TODO: add these with FP extension 
                --exe.csr.mstatus(FS) <= ; TODO: add these with FP extension 
                --exe.csr.mstatus(SD) <= ; TODO: add these with FP extension
                
                exe.csr.mstatus(MPIE) <= ;
                
                exe.csr.mip(MSI) <=
                exe.csr.mip(MTI) <=
                exe.csr.mip(MEI) <=

                exe.csr.mcycle   <= 
                exe.csr.minstret <=

                exe.csr.mepc(1 downto 0)  <= b"00";
                exe.csr.mepc(31 downto 2) <= ;

                exe.csr.mcause(INTR) <= 
                exe.csr.mcause(CODE) <= 

                if then
                    

                elsif  then
                
                else 
                
                end if;
            end if; 
        end if;
    end process;


    -- Read Access
    ap_csr_rd : process(all)
    begin 

        exe.csr_rdata <= (others=>'0'); -- default

        if exe.ctrl.sys then
            case exe.imm32(11 downto 0) is
                
                --when CSR_FFLAGS  => exe.csr_rdata <= exe.csr.fflags; TODO: add these with FP extension
                --when CSR_FRM     => exe.csr_rdata <= exe.csr.frm   ; TODO: add these with FP extension
                --when CSR_FCSR    => exe.csr_rdata <= exe.csr.fcsr  ; TODO: add these with FP extension

                when CSR_TIME =>
                    exe.csr_rdata <= exe.csr.mtime; 
            
                when CSR_MHARTID =>
                    exe.csr_rdata  <= HART_ID;

                when CSR_MSTATUS =>
                    exe.csr_rdata(MIE)  <= exe.csr.mstatus(MIE) ;
                    exe.csr_rdata(MPIE) <= exe.csr.mstatus(MPIE);
                    --exe.csr_rdata(FS)   <= exe.csr.mstatus(FS)  ; TODO: add these with FP extension
                    --exe.csr_rdata(SD)   <= exe.csr.mstatus(SD)  ; TODO: add these with FP extension
                
                when CSR_MTVEC =>
                    exe.csr_rdata(MODE) <= b"00"; -- Direct mode - All exceptions set PC to BASE
                    exe.csr_rdata(BASE) <= TRAP_ADDR(31 downto 2); 

                when CSR_MIE =>
                    exe.csr_rdata(MSI) <= exe.csr.mie(MSI); 
                    exe.csr_rdata(MTI) <= exe.csr.mie(MTI); 
                    exe.csr_rdata(MEI) <= exe.csr.mie(MEI); 

                when CSR_MIP =>
                    exe.csr_rdata(MSI) <= exe.csr.mip(MSI); 
                    exe.csr_rdata(MTI) <= exe.csr.mip(MTI); 
                    exe.csr_rdata(MEI) <= exe.csr.mip(MEI); 

                when CSR_MCYCLE | CSR_CYCLE =>
                    exe.csr_rdata <= exe.csr.mcycle; 

                when CSR_MINSTRET | CSR_INSTRET =>
                    exe.csr_rdata <= exe.csr.minstret; 
                
                when CSR_MCOUNTINHIBIT => 
                    exe.csr_rdata(CY) <= exe.csr.mcountinhibit(CY); 
                    exe.csr_rdata(IR) <= exe.csr.mcountinhibit(IR);

                when CSR_MEPC =>
                    exe.csr_rdata(1 downto 0)  <= b"00";
                    exe.csr_rdata(31 downto 2) <= exe.csr.mepc(31 downto 2);

                when CSR_MCAUSE =>
                    exe.csr_rdata(INTR) => exe.csr.mcause(INTR);
                    exe.csr_rdata(CODE) => exe.csr.mcause(CODE);

                when others =>
                    null;
            end case;
        end if;
    end process; 

    -- Select between the ALU and CSRs for data to feed to next stage
    exe.exe_rslt <= exe.csr_rdata when exe.ctrl.sys else exe.alu_rslt; 


    
    -- Execute => Memory registers
    sp_exe_mem_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
            
            else 
                mem.ctrl     <= exe.ctrl; 
                mem.exe_rslt <= exe.exe_rslt;
                mem.rs2_dat  <= exe.rs2_dat;
                mem.funct3   <= exe.funct3; 
                mem.pc4      <= exe.pc4; 
                mem.rdst_adr <= exe.rdst_adr; 
            end if;
        end if;
    end process;


    -- =========================================================================
    -- Memory ==================================================================
    -- =========================================================================
    -- 
    o_dren <= mem.ctrl.mem_rd;  
    o_dwen <= mem.ctrl.mem_wr;       
    o_daddr <= mem.exe_rslt; 
    o_dwdat <= mem.rs2_dat; 
    
    mem.data_ma_adr_excpt <= o_daddr(1) or o_daddr(0);
    wrb.data_access_excpt <= i_derror;

    o_dfence <= '0'; -- TODO:  
    --i_dstall   


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



    -- Memory => Writeback registers
    sp_mem_wrb_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
            
            else 
                wrb.ctrl     <= mem.ctrl; 
                wrb.exe_rslt <= mem.exe_rslt;
                wrb.pc4      <= mem.pc4; 
                wrb.rdst_adr <= mem.rdst_adr;
            end if;
        end if;
    end process;


    -- =========================================================================
    -- Writeback ===============================================================
    -- =========================================================================
    ap_wrb_mux : process (all) 
    begin
        case (wrb.ctrl.wrb_sel) is 
            when WRB_SEL_EXE_RESULT => wrb.rdst_dat <= wrb.exe_rslt;
            when WRB_SEL_MEM        => wrb.rdst_dat <= wrb.memrd_dat;
            when WRB_SEL_PC4        => wrb.rdst_dat <= wrb.pc4; 
            when others             => wrb.rdst_dat <= (others=>'-');
        end case; 
    end process; 



    -- TODO: execptions & wfi, CSRs, hazards (stalls) & forwarding 
    -- TODO: once I have the cpu implemented and tested, experiment with different
    -- architecture decisions to try to speed things up (for example synchronous
    -- register file reads / branch resolution in exe)



    -- =========================================================================
    -- Hazard Unit =============================================================
    -- =========================================================================
    

    -- =========================================================================
    -- Performance Counters ====================================================
    -- =========================================================================
    







end architecture;










