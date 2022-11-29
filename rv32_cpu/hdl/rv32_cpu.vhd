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
        G_HART_ID    : std_logic_vector(31 downto 0) := x"0000_0000";
        G_RESET_ADDR : std_logic_vector(31 downto 0) := x"0000_0000";
        G_TRAP_ADDR  : std_logic_vector(31 downto 0) := x"0000_1000"
    );
    port (
        -- Clock & Reset
        i_clk       : in  std_logic; 
        i_rst       : in  std_logic; 
        
        -- Instruction  Interface 
        o_iren      : out std_logic;
        o_iaddr     : out std_logic_vector(31 downto 0);
        o_fencei    : out std_logic;
        i_irdat     : in  std_logic_vector(31 downto 0);
        i_istall    : in  std_logic;
        i_ierror    : in  std_logic;

        -- Data Interface 
        o_dren      : out std_logic;
        o_dwen      : out std_logic;
        o_dben      : out std_logic_vector(3 downto 0); -- byte enable 
        o_daddr     : out std_logic_vector(31 downto 0);
        o_dwdat     : out std_logic_vector(31 downto 0);
        o_fence     : out std_logic;
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
        i_db_halt   : in  std_logic;
        i_mtime     : in std_logic_vector(31 downto 0)

    );
end entity;


architecture rtl of rv32_cpu is

   -- Pipeline stage signals
   -- Signals associated with a stage can either come from the pipeline register
   -- before that phase or be set combinationally within that stage.
   signal fet : fet_t; 
   signal dec : dec_t; 
   signal exe : exe_t;
   signal mem : mem_t;  
   signal wrb : wrb_t;

   -- Hazard unit signals 
   signal haz : haz_t; 

   -- Performance counter signals
   signal cnt : cnt_t; 

begin
    --TODO: implement this when I add stalling on WFI instruction 
    o_sleep <= '0'; 
    
    -- TODO: Eventualy maybe add a debugger. This is low priority. 
    o_debug <= '0'; 

    -- =========================================================================
    -- Fetch Stage =============================================================
    -- =========================================================================
    
    -- Handle Interrupts & Exceptions ------------------------------------------
    -- -------------------------------------------------------------------------
    -- Delay the interrupt pending bits by 1 so we can detect a rising edge 
    -- NOTE: The csr.mip bits are tied directly to the i_mX_irq input signals
    process (i_clk)
    begin
        if (rising_edge(i_clk)) then
            if (i_rst) then
                fet.dly_mip_msi <= '0';
                fet.dly_mip_mti <= '0';
                fet.dly_mip_mei <= '0';
            else
                fet.dly_mip_msi <= exe.csr.mip_msi;
                fet.dly_mip_mti <= exe.csr.mip_mti;
                fet.dly_mip_mei <= exe.csr.mip_mei;
            end if;
        end if;
    end process;

    -- Set the PC to the trap address for an interrupt if:
    -- 1.  Interrupts are enabled globally 
    -- 2.  The specific interrupt is enabled
    -- 3a. The specific interrupt has gone from not pending to pending -OR-
    -- 3b. An interrupt is pending after returning from the last 
    --     interrupt service routine 
    -- NOTE: This does not handle nested interrupts. For example, if mt_irq_pulse goes high, 
    -- the flow jumps to the trap addr, the isr starts, and then mt_irq_pulse goes high again, 
    -- the the flow will jump to the trap addr again, even if we haven't gotten an mret
    -- instruciton. In practice this shouldn't be an issue (assuming the NVIC external to the 
    -- cpu is designed well)
    fet.ms_irq_pulse <= (exe.csr.mip_msi and (not fet.dly_mip_msi or dec.mret)) and exe.csr.mie_msi and exe.csr.mstatus_mie; 
    fet.mt_irq_pulse <= (exe.csr.mip_mti and (not fet.dly_mip_mti or dec.mret)) and exe.csr.mie_mti and exe.csr.mstatus_mie; 
    fet.me_irq_pulse <= (exe.csr.mip_mei and (not fet.dly_mip_mei or dec.mret)) and exe.csr.mie_mei and exe.csr.mstatus_mie; 

    
    -- All Exceptions and Interrupts
    fet.trap_taken <= fet.ms_irq_pulse or fet.mt_irq_pulse or fet.me_irq_pulse or 
            mem.load_adr_ma_excpt or mem.load_access_excpt or 
            mem.store_adr_ma_excpt or mem.store_access_excpt or 
            dec.illeg_instr_excpt or dec.ecall_excpt or dec.ebreak_excpt or 
            fet.instr_adr_ma_excpt or fet.instr_access_excpt; 



    -- Program Counter ---------------------------------------------------------
    -- -------------------------------------------------------------------------
    sp_pc : process (i_clk) 
    begin
        if (rising_edge(i_clk)) then
            if (i_rst) then
                fet.instret_incr <= '1'; 
                fet.pc <= G_RESET_ADDR(31 downto 2) & b"00";
            elsif (haz.pc_enable) then

                -- instret_incr increments the instructions retired performance counter
                -- The value starts off as '1' for an enabled fetch, but it can get
                -- overwritten with a zero at any stage if that instruction gets flushed. 
                -- It will also get overwritten with a zero in the wrb stage if that 
                -- stage is stalled (because we dont want to "double count" a stalled valid 
                -- instruction) wrb.instret_incr is what finally gets used to increment 
                -- the performance counter 
                fet.instret_incr <= '1'; 

                if (dec.mret) then
                    fet.pc <= exe.csr.mepc(31 downto 2) & b"00";
                elsif (fet.trap_taken) then -- Must have higher priority than branch 
                    fet.pc <= G_TRAP_ADDR(31 downto 2) & b"00";
                elsif (dec.br_taken) then
                    fet.pc <= dec.brt_adr; 
                else 
                    fet.pc <= std_logic_vector(unsigned(fet.pc) + 4);  
                end if;
            end if;
        end if; 
    end process;
    
    fet.instr_adr_ma_excpt <= (fet.pc(0) or fet.pc(1)) and o_iren;
    fet.instr_access_excpt <= i_ierror and o_iren; 

    o_iren <= '1'; 
    o_iaddr   <= fet.pc;
    dec.instr <= i_irdat;


    -- =========================================================================
    -- Fetch/Decode Registers ==================================================
    -- =========================================================================
    sp_fet_dec_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst or haz.dec_flush) then
                dec.instret_incr       <= '0'; 
                dec.ms_irq_pulse       <= '0'; 
                dec.mt_irq_pulse       <= '0'; 
                dec.me_irq_pulse       <= '0'; 
                dec.instr_adr_ma_excpt <= '0'; 
                dec.instr_access_excpt <= '0'; 
                dec.pc                 <= (others=>'-'); 
            elsif (haz.dec_enable) then
                dec.instret_incr       <= fet.instret_incr; 
                dec.ms_irq_pulse       <= fet.ms_irq_pulse;
                dec.mt_irq_pulse       <= fet.mt_irq_pulse;
                dec.me_irq_pulse       <= fet.me_irq_pulse;
                dec.instr_adr_ma_excpt <= fet.instr_adr_ma_excpt;
                dec.instr_access_excpt <= fet.instr_access_excpt;
                dec.pc                 <= fet.pc; 
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


    -- Register File -----------------------------------------------------------
    -- -------------------------------------------------------------------------
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
            if wrb.ctrl.reg_wr = '1' and wrb.rdst_adr /= b"00000" then
                dec.regfile(to_integer(unsigned(wrb.rdst_adr))) <= wrb.rdst_dat; 
            end if; 
        end if;
    end process;

    -- Async Reads. Needs to be async so I can handle branch resolution in dec stage.
    ap_regfile_read : process (all)
    begin
        if dec.rs1_adr = b"00000" then
            dec.rs1_dat <= (others=>'0');
        else
            dec.rs1_dat <= dec.regfile(to_integer(unsigned(dec.rs1_adr)));
        end if;

        if dec.rs2_adr = b"00000" then
            dec.rs2_dat <= (others=>'0');
        else
            dec.rs2_dat <= dec.regfile(to_integer(unsigned(dec.rs2_adr)));
        end if;
    end process;


    -- Control Unit ------------------------------------------------------------
    -- -------------------------------------------------------------------------
    ap_ctrl : process (all)
    begin
        case (dec.opcode) is
            when OPCODE_LUI => 
                dec.ctrl.reg_wr   <= '1';
                dec.ctrl.wrb_sel  <= WRB_SEL_EXE;
                dec.ctrl.mem_wr   <= '0';
                dec.ctrl.mem_rd   <= '0'; 
                dec.ctrl.alu_ctrl <= ALU_CTRL_ADD; 
                dec.ctrl.alua_sel <= ALU_A_ZERO;
                dec.ctrl.alub_sel <= ALU_B_IMM32;
                dec.ctrl.jal      <= '0';
                dec.ctrl.jalr     <= '0';
                dec.ctrl.branch   <= '0';
                dec.ctrl.imm_type <= UTYPE;
                dec.ctrl.sys      <= '0'; 
                dec.ctrl.fence    <= '0';
                dec.ctrl.illegal  <= '0'; 
    
            when OPCODE_AUIPC => 
                dec.ctrl.reg_wr   <= '1';
                dec.ctrl.wrb_sel  <= WRB_SEL_EXE;
                dec.ctrl.mem_wr   <= '0';
                dec.ctrl.mem_rd   <= '0';
                dec.ctrl.alu_ctrl <= ALU_CTRL_ADD; 
                dec.ctrl.alua_sel <= ALU_A_PC;
                dec.ctrl.alub_sel <= ALU_B_IMM32;
                dec.ctrl.jal      <= '0';
                dec.ctrl.jalr     <= '0';
                dec.ctrl.branch   <= '0';
                dec.ctrl.imm_type <= UTYPE;
                dec.ctrl.sys      <= '0'; 
                dec.ctrl.fence    <= '0';
                dec.ctrl.illegal  <= '0'; 
    
            when OPCODE_ALUI  =>
                dec.ctrl.reg_wr   <= '1';
                dec.ctrl.wrb_sel  <= WRB_SEL_EXE;
                dec.ctrl.mem_wr   <= '0';
                dec.ctrl.mem_rd   <= '0';
                dec.ctrl.alu_ctrl <= ALU_CTRL_ALU;
                dec.ctrl.alua_sel <= ALU_A_RS1;
                dec.ctrl.alub_sel <= ALU_B_IMM32;
                dec.ctrl.jal      <= '0';
                dec.ctrl.jalr     <= '0';
                dec.ctrl.branch   <= '0';
                dec.ctrl.imm_type <= ITYPE;
                dec.ctrl.sys      <= '0'; 
                dec.ctrl.fence    <= '0';
                dec.ctrl.illegal  <= '0'; 
    
            when OPCODE_ALUR  =>
                dec.ctrl.reg_wr   <= '1';
                dec.ctrl.wrb_sel  <= WRB_SEL_EXE;
                dec.ctrl.mem_wr   <= '0';
                dec.ctrl.mem_rd   <= '0';
                dec.ctrl.alu_ctrl <= ALU_CTRL_ALU;
                dec.ctrl.alua_sel <= ALU_A_RS1;
                dec.ctrl.alub_sel <= ALU_B_RS2;
                dec.ctrl.jal      <= '0';
                dec.ctrl.jalr     <= '0';
                dec.ctrl.branch   <= '0';
                dec.ctrl.imm_type <= RTYPE;
                dec.ctrl.sys      <= '0'; 
                dec.ctrl.fence    <= '0';
                dec.ctrl.illegal  <= '0'; 
    
            when OPCODE_JAL  =>  
                dec.ctrl.reg_wr   <= '1';
                dec.ctrl.wrb_sel  <= WRB_SEL_PC4; 
                dec.ctrl.mem_wr   <= '0';
                dec.ctrl.mem_rd   <= '0';
                dec.ctrl.alu_ctrl <= '-';  
                dec.ctrl.alua_sel <= b"--";   
                dec.ctrl.alub_sel <= '-'; 
                dec.ctrl.jal      <= '1';
                dec.ctrl.jalr     <= '0';
                dec.ctrl.branch   <= '0';
                dec.ctrl.imm_type <= JTYPE;
                dec.ctrl.sys      <= '0'; 
                dec.ctrl.fence    <= '0';
                dec.ctrl.illegal  <= '0'; 
    
            when OPCODE_JALR =>  
                dec.ctrl.reg_wr   <= '1';
                dec.ctrl.wrb_sel  <= WRB_SEL_PC4; 
                dec.ctrl.mem_wr   <= '0';
                dec.ctrl.mem_rd   <= '0';
                dec.ctrl.alu_ctrl <= '-';  
                dec.ctrl.alua_sel <= b"--";  
                dec.ctrl.alub_sel <= '-'; 
                dec.ctrl.jal      <= '0';
                dec.ctrl.jalr     <= '1';
                dec.ctrl.branch   <= '0';
                dec.ctrl.imm_type <= ITYPE;
                dec.ctrl.sys      <= '0'; 
                dec.ctrl.fence    <= '0';
                dec.ctrl.illegal  <= '0'; 
    
            when OPCODE_BRANCH =>
                dec.ctrl.reg_wr   <= '0';
                dec.ctrl.wrb_sel  <= b"--";
                dec.ctrl.mem_wr   <= '0';
                dec.ctrl.mem_rd   <= '0';
                dec.ctrl.alu_ctrl <= '-';  
                dec.ctrl.alua_sel <= b"--";
                dec.ctrl.alub_sel <= '-'; 
                dec.ctrl.jal      <= '0';
                dec.ctrl.jalr     <= '0';
                dec.ctrl.branch   <= '1';
                dec.ctrl.imm_type <= BTYPE;
                dec.ctrl.sys      <= '0'; 
                dec.ctrl.fence    <= '0';
                dec.ctrl.illegal  <= '0'; 
    
            when OPCODE_LOAD =>
                dec.ctrl.reg_wr   <= '1';
                dec.ctrl.wrb_sel  <= WRB_SEL_MEM;
                dec.ctrl.mem_wr   <= '0';
                dec.ctrl.mem_rd   <= '1';
                dec.ctrl.alu_ctrl <= ALU_CTRL_ADD;
                dec.ctrl.alua_sel <= ALU_A_RS1;
                dec.ctrl.alub_sel <= ALU_B_IMM32;
                dec.ctrl.jal      <= '0';
                dec.ctrl.jalr     <= '0';
                dec.ctrl.branch   <= '0';
                dec.ctrl.imm_type <= ITYPE;
                dec.ctrl.sys      <= '0'; 
                dec.ctrl.fence    <= '0';
                dec.ctrl.illegal  <= '0'; 
    
            when OPCODE_STORE =>
                dec.ctrl.reg_wr   <= '0';
                dec.ctrl.wrb_sel  <= b"--";
                dec.ctrl.mem_wr   <= '1';
                dec.ctrl.mem_rd   <= '0';
                dec.ctrl.alu_ctrl <= ALU_CTRL_ADD;
                dec.ctrl.alua_sel <= ALU_A_RS1;
                dec.ctrl.alub_sel <= ALU_B_IMM32;
                dec.ctrl.jal      <= '0';
                dec.ctrl.jalr     <= '0';
                dec.ctrl.branch   <= '0';
                dec.ctrl.imm_type <= STYPE; 
                dec.ctrl.sys      <= '0'; 
                dec.ctrl.fence    <= '0';
                dec.ctrl.illegal  <= '0'; 
    
            when OPCODE_FENCE =>
                dec.ctrl.reg_wr   <= '0';
                dec.ctrl.wrb_sel  <= b"--";
                dec.ctrl.mem_wr   <= '0';
                dec.ctrl.mem_rd   <= '0';
                dec.ctrl.alu_ctrl <= '-';  
                dec.ctrl.alua_sel <= b"--";
                dec.ctrl.alub_sel <= '-'; 
                dec.ctrl.jal      <= '0';
                dec.ctrl.jalr     <= '0';
                dec.ctrl.branch   <= '0';
                dec.ctrl.imm_type <= b"---"; 
                dec.ctrl.sys      <= '0'; 
                dec.ctrl.fence    <= '1';
                dec.ctrl.illegal  <= '0'; 
    
            -- NOTE: csr, ecall, ebreak, mret, and wfi instructions. 
            -- only csr uses reg wr = '1', but its okay that this is set to 1 for the other
            -- instructions because they have their rs1 and rdst fields set to 0, meaning 
            -- that no write will actually happen and forwarding will not get triggered.
            when OPCODE_SYSTEM =>
                dec.ctrl.reg_wr   <= '1';
                dec.ctrl.wrb_sel  <= WRB_SEL_EXE;
                dec.ctrl.mem_wr   <= '0';
                dec.ctrl.mem_rd   <= '0';
                dec.ctrl.alu_ctrl <= '-';  
                dec.ctrl.alua_sel <= b"--";
                dec.ctrl.alub_sel <= '-'; 
                dec.ctrl.jal      <= '0';
                dec.ctrl.jalr     <= '0';
                dec.ctrl.branch   <= '0';
                dec.ctrl.imm_type <= ITYPE; 
                dec.ctrl.sys      <= '1'; 
                dec.ctrl.fence    <= '0';
                dec.ctrl.illegal  <= '0'; 
    
            when others =>
                dec.ctrl.reg_wr   <= '0';
                dec.ctrl.wrb_sel  <= b"--";
                dec.ctrl.mem_wr   <= '0';
                dec.ctrl.mem_rd   <= '0';
                dec.ctrl.alu_ctrl <= '-';  
                dec.ctrl.alua_sel <= b"--";
                dec.ctrl.alub_sel <= '-'; 
                dec.ctrl.jal      <= '0';
                dec.ctrl.jalr     <= '0';
                dec.ctrl.branch   <= '0';
                dec.ctrl.imm_type <= b"---"; 
                dec.ctrl.sys      <= '0'; 
                dec.ctrl.fence    <= '0';
                dec.ctrl.illegal  <= '1'; 
        end case; 
    end process;

    -- Illegal instruction exception
    dec.illeg_instr_excpt <= dec.ctrl.illegal and dec.instret_incr;
 

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

    -- Forwarding Muxes
    ap_dec_fw_sel : process (all) 
    begin 
        case (haz.dec_fw_rs1_sel) is 
            when WRB_FW => dec.dec_fw_rs1_dat <= wrb.rdst_dat;
            when MEM_FW => dec.dec_fw_rs1_dat <= mem.exe_rslt;
            when others => dec.dec_fw_rs1_dat <= dec.rs1_dat;
        end case; 

        case (haz.dec_fw_rs2_sel) is 
            when WRB_FW => dec.dec_fw_rs2_dat <= wrb.rdst_dat;
            when MEM_FW => dec.dec_fw_rs2_dat <= mem.exe_rslt;
            when others => dec.dec_fw_rs2_dat <= dec.rs2_dat;
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

        dec.br_eq  <= '1' when dec.dec_fw_rs1_dat = dec.dec_fw_rs2_dat else '0'; 
        dec.br_ltu <= '1' when unsigned(dec.dec_fw_rs1_dat) < unsigned(dec.dec_fw_rs2_dat) else '0'; 
        dec.br_lt  <= '1' when signed(dec.dec_fw_rs1_dat) < signed(dec.dec_fw_rs2_dat) else '0'; 

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
            v_brt_adr := std_logic_vector(signed(dec.imm32) + signed(dec.dec_fw_rs1_dat)); 
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
        dec.ecall_excpt  <= '0'; 
        dec.ebreak_excpt <= '0'; 
        dec.mret         <= '0';
        dec.wfi          <= '0';
        dec.csr_access   <= '0'; 

        if (dec.ctrl.sys) then
            if (dec.funct3 = F3_ENV) then
                case (dec.imm32(11 downto 0)) is 
                    when F12_ECALL  => dec.ecall_excpt  <= '1'; 
                    when F12_EBREAK => dec.ebreak_excpt <= '1'; 
                    when F12_MRET   => dec.mret         <= '1';
                    when F12_WFI    => dec.wfi          <= '1';
                    when others     => null;
                end case; 
            else 
                dec.csr_access <= '1'; 
            end if;
        end if; 
    end process;

    -- Fence Instructions ------------------------------------------------------
    -- -------------------------------------------------------------------------
    dec.fence  <= '1' when dec.ctrl.fence = '1' and dec.funct3 = F3_FENCE  else '0'; 
    dec.fencei <= '1' when dec.ctrl.fence = '1' and dec.funct3 = F3_FENCEI else '0';
    o_fence   <= dec.fence;  
    o_fencei  <= dec.fencei;


    -- =========================================================================
    -- Decode/Execute Registers ================================================
    -- =========================================================================
    sp_dec_exe_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst or haz.exe_flush) then
                exe.instret_incr       <= '0'; 
                exe.ms_irq_pulse       <= '0'; 
                exe.mt_irq_pulse       <= '0'; 
                exe.me_irq_pulse       <= '0'; 
                exe.instr_adr_ma_excpt <= '0'; 
                exe.instr_access_excpt <= '0'; 
                exe.illeg_instr_excpt  <= '0'; 
                exe.ecall_excpt        <= '0'; 
                exe.ebreak_excpt       <= '0'; 
                exe.ctrl.reg_wr        <= '0'; 
                exe.ctrl.wrb_sel       <= (others=>'-');
                exe.ctrl.mem_wr        <= '0'; 
                exe.ctrl.mem_rd        <= '0'; 
                exe.ctrl.alu_ctrl      <= '-';
                exe.ctrl.alua_sel      <= (others=>'-');
                exe.ctrl.alub_sel      <= '-';
                exe.csr_access         <= '0';
                exe.pc                 <= (others=>'-');
                exe.rs1_adr            <= (others=>'-');
                exe.rs2_adr            <= (others=>'-');
                exe.rdst_adr           <= (others=>'-');
                exe.rs1_dat            <= (others=>'-');
                exe.rs2_dat            <= (others=>'-');
                exe.imm32              <= (others=>'-');
                exe.funct3             <= (others=>'-');
                exe.funct7             <= (others=>'-');
                exe.is_rtype           <= '-';
            elsif (haz.exe_enable) then
                exe.instret_incr       <= dec.instret_incr; 
                exe.ms_irq_pulse       <= dec.ms_irq_pulse;
                exe.mt_irq_pulse       <= dec.mt_irq_pulse;
                exe.me_irq_pulse       <= dec.me_irq_pulse;
                exe.instr_adr_ma_excpt <= dec.instr_adr_ma_excpt;
                exe.instr_access_excpt <= dec.instr_access_excpt;
                exe.illeg_instr_excpt  <= dec.illeg_instr_excpt;
                exe.ecall_excpt        <= dec.ecall_excpt;
                exe.ebreak_excpt       <= dec.ebreak_excpt;
                exe.ctrl.reg_wr        <= dec.ctrl.reg_wr;
                exe.ctrl.wrb_sel       <= dec.ctrl.wrb_sel;
                exe.ctrl.mem_wr        <= dec.ctrl.mem_wr;
                exe.ctrl.mem_rd        <= dec.ctrl.mem_rd;
                exe.ctrl.alu_ctrl      <= dec.ctrl.alu_ctrl;
                exe.ctrl.alua_sel      <= dec.ctrl.alua_sel;
                exe.ctrl.alub_sel      <= dec.ctrl.alub_sel;
                exe.csr_access         <= dec.csr_access;
                exe.pc                 <= dec.pc;
                exe.rs1_adr            <= dec.rs1_adr;
                exe.rs2_adr            <= dec.rs2_adr;
                exe.rdst_adr           <= dec.rdst_adr;
                exe.rs1_dat            <= dec.dec_fw_rs1_dat;
                exe.rs2_dat            <= dec.dec_fw_rs2_dat;
                exe.imm32              <= dec.imm32; 
                exe.funct3             <= dec.funct3;
                exe.funct7             <= dec.funct7;
                -- Is this an R-Type instruction? Used for making alu opcode.
                exe.is_rtype <= '1' when dec.ctrl.imm_type = RTYPE else '0';
            end if; 
        end if;
    end process;

    -- =========================================================================
    -- Execute Stage ===========================================================
    -- =========================================================================
   
    -- Forwarding Muxes
    ap_exe_fw_sel : process (all) 
    begin 
        case (haz.exe_fw_rs1_sel) is 
            when WRB_FW => exe.exe_fw_rs1_dat <= wrb.rdst_dat;
            when MEM_FW => exe.exe_fw_rs1_dat <= mem.exe_rslt;
            when others => exe.exe_fw_rs1_dat <= exe.rs1_dat;
        end case; 

        case (haz.exe_fw_rs2_sel) is 
            when WRB_FW => exe.exe_fw_rs2_dat <= wrb.rdst_dat;
            when MEM_FW => exe.exe_fw_rs2_dat <= mem.exe_rslt;
            when others => exe.exe_fw_rs2_dat <= exe.rs2_dat;
        end case; 
    end process; 

    -- Integer ALU -------------------------------------------------------------
    -- -------------------------------------------------------------------------
    ap_int_alu: process (all) 
    begin 
        -- Select the first ALU operand
        case (exe.ctrl.alua_sel) is 
            when ALU_A_RS1     => exe.alua_dat <= exe.exe_fw_rs1_dat; 
            when ALU_A_PC      => exe.alua_dat <= exe.pc; 
            when ALU_A_ZERO    => exe.alua_dat <= (others=>'0'); 
            when others        => exe.alua_dat <= (others=>'-'); 
        end case; 

        -- Select the second ALU operand
        case (exe.ctrl.alub_sel) is 
            when ALU_B_RS2   => exe.alub_dat <= exe.exe_fw_rs2_dat; 
            when ALU_B_IMM32 => exe.alub_dat <= exe.imm32; 
            when others      => exe.alub_dat <= (others=>'-'); 
        end case;

        -- Build the aluop
        case (exe.ctrl.alu_ctrl) is 
            when ALU_CTRL_ADD => 
                exe.aluop <= ALUOP_ADD;  

            when ALU_CTRL_ALU => 
                case (exe.funct3) is
                    when F3_SUBADD =>
                        if (exe.is_rtype and exe.funct7(5)) then
                            exe.aluop <= ALUOP_SUB;
                        else
                            exe.aluop <= ALUOP_ADD;
                        end if;

                    when F3_SR =>
                        if (exe.funct7(5)) then
                            exe.aluop <= ALUOP_SRA;
                        else
                            exe.aluop <= ALUOP_SRL;
                        end if; 

                    when F3_SLL => exe.aluop <= ALUOP_SLL ;
                    when F3_SLT => exe.aluop <= ALUOP_SLT ;  
                    when F3_SLTU=> exe.aluop <= ALUOP_SLTU;  
                    when F3_XOR => exe.aluop <= ALUOP_XOR ;   
                    when F3_OR  => exe.aluop <= ALUOP_OR  ; 
                    when F3_AND => exe.aluop <= ALUOP_AND ; 
                    when others => exe.aluop <= (others=>'-'); 
                end case;
            when others => exe.aluop <= (others=>'-'); 
        end case; 

        -- ALU
        case (exe.aluop) is
            when ALUOP_ADD  => exe.alu_rslt <= 
                std_logic_vector(signed(exe.alua_dat) + signed(exe.alub_dat)); 

            when ALUOP_SUB  => exe.alu_rslt <= 
                std_logic_vector(signed(exe.alua_dat) - signed(exe.alub_dat));

            when ALUOP_SLL  => exe.alu_rslt <= 
                std_logic_vector(shift_left(unsigned(exe.alua_dat), 
                to_integer(unsigned(exe.alub_dat(4 downto 0)))));

            when ALUOP_SLT  => exe.alu_rslt <= 
                x"0000_0001" when (signed(exe.alua_dat) < signed(exe.alub_dat))  
                else x"0000_0000"; 

            when ALUOP_SLTU => exe.alu_rslt <=
                x"0000_0001" when (unsigned(exe.alua_dat) < unsigned(exe.alub_dat)) 
                else x"0000_0000"; 

            when ALUOP_XOR  => exe.alu_rslt <= 
                exe.alua_dat xor exe.alub_dat; 

            when ALUOP_SRL  => exe.alu_rslt <= 
                std_logic_vector(shift_right(unsigned(exe.alua_dat), 
                to_integer(unsigned(exe.alub_dat(4 downto 0)))));    

            when ALUOP_SRA  => exe.alu_rslt <= 
                std_logic_vector(shift_right(signed(exe.alua_dat),
                to_integer(unsigned(exe.alub_dat(4 downto 0)))));

            when ALUOP_OR   => exe.alu_rslt <= 
                exe.alua_dat or exe.alub_dat; 

            when ALUOP_AND  => exe.alu_rslt <= 
                exe.alua_dat and exe.alub_dat; 
                
            when others     => exe.alu_rslt <= 
                (others=>'-');
        end case; 
    end process; 
 
   
    -- CSR Access --------------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Generate the csr write data (for SW writes)
    ap_csr_wdata : process (all)
    begin
        case exe.funct3 is 
            when F3_CSRRW =>  
                exe.csr_wdata <= exe.exe_fw_rs1_dat;

            when F3_CSRRS =>
                exe.csr_wdata <= exe.exe_fw_rs1_dat or exe.csr_rdata;

            when F3_CSRRC =>
                exe.csr_wdata <= not exe.exe_fw_rs1_dat and exe.csr_rdata;

            when F3_CSRRWI =>  
                exe.csr_wdata(31 downto 5) <= (others=>'0');
                exe.csr_wdata(4 downto 0)  <= exe.rs1_adr;

            when F3_CSRRSI =>
                exe.csr_wdata(31 downto 5) <= exe.csr_rdata(31 downto 5);
                exe.csr_wdata(4 downto 0)  <= exe.rs1_adr or exe.csr_rdata(4 downto 0);

            when F3_CSRRCI =>
                exe.csr_wdata(31 downto 5) <= (others=>'0');
                exe.csr_wdata(4 downto 0)  <= not exe.rs1_adr and exe.csr_rdata(4 downto 0);

            when others    => 
                exe.csr_wdata <= (others=>'-');
        end case; 
    end process;

    -- Was there a trap? 
    -- Memory stage exceptions are forwarded to this stage
    -- All others are generated at or before this stage
    exe.any_trap <= exe.ms_irq_pulse or exe.mt_irq_pulse or exe.me_irq_pulse or 
                    mem.load_adr_ma_excpt or mem.load_access_excpt or 
                    mem.store_adr_ma_excpt or mem.store_access_excpt or 
                    exe.ctrl.illegal or exe.ecall_excpt or exe.ebreak_excpt or 
                    exe.instr_adr_ma_excpt or exe.instr_access_excpt; 

    -- Writes
    sp_csr_wr : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                -- These are the only CSRs that need to be reset to a specific value
                -- All others are undefined according to the spec. This means that 
                -- SW must initialize the undefined CSRs
                exe.csr.mstatus_mie  <= '0';
                exe.csr.mcause_intr  <= '0';
                exe.csr.mcause_code  <= (others=>'0');

                exe.csr.mstatus_mpie <= '-';
                exe.csr.mie_msi      <= '-';
                exe.csr.mie_mti      <= '-';
                exe.csr.mie_mei      <= '-';
                exe.csr.mip_msi      <= '-';
                exe.csr.mip_mti      <= '-';
                exe.csr.mip_mei      <= '-';
                exe.csr.mepc         <= (others=>'-');
                exe.csr.mcycle       <= (others=>'-');
                exe.csr.minstret     <= (others=>'-');

            -- Software writes by CSR instructions
            -- SW Writes take priority over HW if both try to write on the same cycle
            else 
                if (exe.csr_access) then
                    case exe.imm32(11 downto 0) is
                        --when CSR_FFLAGS  => TODO: 
                        --when CSR_FRM     =>
                        --when CSR_FCSR    =>

                        when CSR_MSTATUS =>
                            exe.csr.mstatus_mie  <= exe.csr_wdata(MIE); 
                            exe.csr.mstatus_mpie <= exe.csr_wdata(MPIE);
                        
                        when CSR_MIE =>
                            exe.csr.mie_msi <= exe.csr_wdata(MSI); 
                            exe.csr.mie_mti <= exe.csr_wdata(MTI); 
                            exe.csr.mie_mei <= exe.csr_wdata(MEI); 
                    
                        when CSR_MEPC =>
                            exe.csr.mepc(31 downto 2) <= exe.csr_wdata(31 downto 2);
                        
                        when CSR_MCYCLE =>
                            exe.csr.mcycle   <= exe.csr_wdata; 
                            
                        when CSR_MINSTRET =>
                            exe.csr.minstret <= exe.csr_wdata; 

                        when others =>
                            null;
                    end case;   
                else

                    -- HW writes by CPU
                    -- 
                    -- TODO: add these with FP extension 
                    --exe.csr.fflags      <= ; 
                    --exe.csr.frm         <= ; 
                    --exe.csr.fcsr        <= ; 
                    --exe.csr.mstatus(FS) <= ; 
                    --exe.csr.mstatus(SD) <= ; 
                    
                    exe.csr.mip_msi <= i_ms_irq;
                    exe.csr.mip_mti <= i_me_irq;
                    exe.csr.mip_mei <= i_mt_irq;

                    exe.csr.mcycle   <= cnt.mcycle; 
                    exe.csr.minstret <= cnt.minstret; 

                    -- Set Previous IE status on a trap 
                    if (exe.any_trap) then
                        exe.csr.mstatus_mpie     <= exe.csr.mstatus_mie;
                    end if;   

                    -- Set the trap cause register and exception program counter
                    -- register 
                    -- Priority defined in risc V spec 
                    -- NOTE: SW is expected to increment the epc to the next instruction 
                    -- for an ecall/ebreak. If SW doesnt do this, then we'll get caught 
                    -- in an ecall / irq handler / mret ... loop 
                    -- I wanted to set the epc to pc+4 for ecall/ebreak, but doing so 
                    -- would violate the RISCV specification
                    if (exe.me_irq_pulse) then
                        exe.csr.mcause_intr      <= '1'; 
                        exe.csr.mcause_code      <= TRAP_MEI_IRQ; --11
                        exe.csr.mepc(31 downto 2) <= exe.pc(31 downto 2);
                    elsif (exe.ms_irq_pulse) then 
                        exe.csr.mcause_intr      <= '1'; 
                        exe.csr.mcause_code      <= TRAP_MSI_IRQ; --3
                        exe.csr.mepc(31 downto 2) <= exe.pc(31 downto 2);
                    elsif (exe.mt_irq_pulse) then
                        exe.csr.mcause_intr      <= '1'; 
                        exe.csr.mcause_code      <= TRAP_MTI_IRQ; --7
                        exe.csr.mepc(31 downto 2) <= exe.pc(31 downto 2);
                    elsif (exe.instr_adr_ma_excpt) then
                        exe.csr.mcause_intr      <= '0'; 
                        exe.csr.mcause_code      <= TRAP_IMA; --0
                        exe.csr.mepc(31 downto 2) <= exe.pc(31 downto 2);
                    elsif (exe.instr_access_excpt) then
                        exe.csr.mcause_intr      <= '0'; 
                        exe.csr.mcause_code      <= TRAP_IACC; --1
                        exe.csr.mepc(31 downto 2) <= exe.pc(31 downto 2);
                    elsif (exe.ctrl.illegal) then
                        exe.csr.mcause_intr      <= '0'; 
                        exe.csr.mcause_code      <= TRAP_ILL_INTR; --2
                        exe.csr.mepc(31 downto 2) <= exe.pc(31 downto 2);
                    elsif (exe.ebreak_excpt) then
                        exe.csr.mcause_intr      <= '0'; 
                        exe.csr.mcause_code      <= TRAP_EBREAK; --3
                        exe.csr.mepc(31 downto 2) <= exe.pc(31 downto 2);
                    elsif (mem.load_adr_ma_excpt) then
                        exe.csr.mcause_intr      <= '0'; 
                        exe.csr.mcause_code      <= TRAP_LMA; --4
                        exe.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    elsif (mem.load_access_excpt) then
                        exe.csr.mcause_intr      <= '0'; 
                        exe.csr.mcause_code      <= TRAP_LACC; --5
                        exe.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    elsif (mem.store_adr_ma_excpt) then
                        exe.csr.mcause_intr      <= '0'; 
                        exe.csr.mcause_code      <= TRAP_SMA; --6
                        exe.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    elsif (mem.store_access_excpt) then
                        exe.csr.mcause_intr      <= '0'; 
                        exe.csr.mcause_code      <= TRAP_SACC; --7
                        exe.csr.mepc(31 downto 2) <= mem.pc(31 downto 2);
                    elsif (exe.ecall_excpt) then
                        exe.csr.mcause_intr      <= '0'; 
                        exe.csr.mcause_code      <= TRAP_MECALL; --11
                        exe.csr.mepc(31 downto 2) <= exe.pc(31 downto 2);
                    end if; 
                end if; 
            end if; 
        end if;
    end process;


    -- Reads
    ap_csr_rd : process(all)
    begin 

        exe.csr_rdata <= (others=>'0'); -- default

        if (exe.csr_access) then
            case exe.imm32(11 downto 0) is
                -- TODO: add these with FP extension
                --when CSR_FFLAGS  => exe.csr_rdata <= exe.csr.fflags; 
                --when CSR_FRM     => exe.csr_rdata <= exe.csr.frm   ;
                --when CSR_FCSR    => exe.csr_rdata <= exe.csr.fcsr  ;

                when CSR_TIME =>
                    exe.csr_rdata  <= i_mtime;
            
                when CSR_MHARTID =>
                    exe.csr_rdata  <= G_HART_ID;

                when CSR_MSTATUS =>
                    exe.csr_rdata(MIE)  <= exe.csr.mstatus_mie ;
                    exe.csr_rdata(MPIE) <= exe.csr.mstatus_mpie;
                    --exe.csr_rdata(FS)   <= exe.csr.mstatus(FS)  ; TODO: add these with FP extension
                    --exe.csr_rdata(SD)   <= exe.csr.mstatus(SD)  ; TODO: add these with FP extension
                
                when CSR_MTVEC =>
                    exe.csr_rdata(MODE) <= b"00"; -- Direct mode - All exceptions set PC to BASE
                    exe.csr_rdata(BASE) <= G_TRAP_ADDR(31 downto 2); 

                when CSR_MIE =>
                    exe.csr_rdata(MSI) <= exe.csr.mie_msi; 
                    exe.csr_rdata(MTI) <= exe.csr.mie_mti; 
                    exe.csr_rdata(MEI) <= exe.csr.mie_mei; 

                when CSR_MIP =>
                    exe.csr_rdata(MSI) <= exe.csr.mip_msi; 
                    exe.csr_rdata(MTI) <= exe.csr.mip_mti; 
                    exe.csr_rdata(MEI) <= exe.csr.mip_mei; 

                when CSR_MCYCLE | CSR_CYCLE =>
                    exe.csr_rdata <= exe.csr.mcycle; 

                when CSR_MINSTRET | CSR_INSTRET =>
                    exe.csr_rdata <= exe.csr.minstret; 

                when CSR_MEPC =>
                    exe.csr_rdata(31 downto 2) <= exe.csr.mepc(31 downto 2);

                when CSR_MCAUSE =>
                    exe.csr_rdata(INTR) <= exe.csr.mcause_intr;
                    exe.csr_rdata(CODE) <= exe.csr.mcause_code;

                when others =>
                    null;
            end case;
        end if;
    end process; 

    -- Execute stage result mux
    exe.exe_rslt <= exe.csr_rdata when exe.csr_access else exe.alu_rslt; 

    
    -- =========================================================================
    -- Execute/Memory Registers ================================================
    -- =========================================================================
    sp_exe_mem_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst or haz.mem_flush) then
                mem.instret_incr <= '0';
                mem.ctrl.reg_wr  <= '0';
                mem.ctrl.wrb_sel <= (others=>'-');
                mem.ctrl.mem_wr  <= '0';
                mem.ctrl.mem_rd  <= '0';
                mem.pc           <= (others=>'-');
                mem.rs2_adr      <= (others=>'-');
                mem.rdst_adr     <= (others=>'-');
                mem.rs2_dat      <= (others=>'-');
                mem.funct3       <= (others=>'-');
                mem.exe_rslt     <= (others=>'-');
            elsif (haz.mem_enable) then
                mem.instret_incr <= exe.instret_incr; 
                mem.ctrl.reg_wr  <= exe.ctrl.reg_wr;
                mem.ctrl.wrb_sel <= exe.ctrl.wrb_sel;
                mem.ctrl.mem_wr  <= exe.ctrl.mem_wr;
                mem.ctrl.mem_rd  <= exe.ctrl.mem_rd;
                mem.pc           <= exe.pc; 
                mem.rs2_adr      <= exe.rs2_adr;
                mem.rdst_adr     <= exe.rdst_adr; 
                mem.rs2_dat      <= exe.exe_fw_rs2_dat;
                mem.funct3       <= exe.funct3; 
                mem.exe_rslt     <= exe.exe_rslt;
            end if; 
        end if;
    end process;


    -- =========================================================================
    -- Memory Stage ============================================================
    -- =========================================================================
    
    -- Forwarding Mux 
    ap_mem_fw_sel : process (all) 
    begin 
        case (haz.mem_fw_rs2_sel) is 
            when WRB_FW => mem.mem_fw_rs2_dat <= wrb.rdst_dat;
            when others => mem.mem_fw_rs2_dat <= mem.rs2_dat;
        end case; 
    end process; 


    -- Memory Access -----------------------------------------------------------
    -- -------------------------------------------------------------------------
    o_dren  <= mem.ctrl.mem_rd;  
    o_dwen  <= mem.ctrl.mem_wr;       
    o_daddr <= mem.exe_rslt; 
    o_dwdat <= mem.mem_fw_rs2_dat; 
    
    mem.load_adr_ma_excpt  <= mem.ctrl.mem_rd and (o_daddr(1) or o_daddr(0));
    mem.load_access_excpt  <= mem.ctrl.mem_rd and i_derror;
    mem.store_adr_ma_excpt <= mem.ctrl.mem_wr and (o_daddr(1) or o_daddr(0));
    mem.store_access_excpt <= mem.ctrl.mem_wr and i_derror;


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


    -- =========================================================================
    -- Memory/Writeback Registers ==============================================
    -- =========================================================================
    sp_mem_wrb_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst or haz.wrb_flush) then
                wrb.instret_incr <= '0'; 
                wrb.ctrl.reg_wr  <= '0'; 
                wrb.ctrl.wrb_sel <= (others=>'-');
                wrb.pc4          <= (others=>'-');
                wrb.rdst_adr     <= (others=>'-');
                wrb.exe_rslt     <= (others=>'-');
            elsif (haz.wrb_enable) then
                wrb.instret_incr <= mem.instret_incr; 
                wrb.ctrl.reg_wr  <= mem.ctrl.reg_wr;
                wrb.ctrl.wrb_sel <= mem.ctrl.wrb_sel;
                wrb.pc4          <= std_logic_vector(unsigned(mem.pc) + 4);
                wrb.rdst_adr     <= mem.rdst_adr;
                wrb.exe_rslt     <= mem.exe_rslt;
            else
                wrb.instret_incr <= '0'; 
            end if; 
        end if;
    end process;


    -- =========================================================================
    -- Writeback Stage =========================================================
    -- =========================================================================
    ap_wrb_sel : process (all) 
    begin
        case (wrb.ctrl.wrb_sel) is 
            when WRB_SEL_EXE => wrb.rdst_dat <= wrb.exe_rslt;
            when WRB_SEL_MEM => wrb.rdst_dat <= wrb.memrd_dat;
            when WRB_SEL_PC4 => wrb.rdst_dat <= wrb.pc4; 
            when others      => wrb.rdst_dat <= (others=>'-');
        end case; 
    end process; 




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
        if    (mem.ctrl.reg_wr = '1' and mem.rdst_adr /= b"00000" and mem.rdst_adr = dec.rs1_adr) then
            haz.dec_fw_rs1_sel <= MEM_FW;
        elsif (wrb.ctrl.reg_wr = '1' and wrb.rdst_adr /= b"00000" and wrb.rdst_adr = dec.rs1_adr) then
            haz.dec_fw_rs1_sel <= WRB_FW;
        else 
            haz.dec_fw_rs1_sel <= NO_FW;
        end if; 
        -- RS2
        if    (mem.ctrl.reg_wr = '1' and mem.rdst_adr /= b"00000" and mem.rdst_adr = dec.rs2_adr) then
            haz.dec_fw_rs2_sel <= MEM_FW;
        elsif (wrb.ctrl.reg_wr = '1' and wrb.rdst_adr /= b"00000" and wrb.rdst_adr = dec.rs2_adr) then
            haz.dec_fw_rs2_sel <= WRB_FW;
        else 
            haz.dec_fw_rs2_sel <= NO_FW;
        end if; 

        -- TODO: can I get rid of some of this???
        -- -- Forwarding to execute stage
        -- -- RS1
        if    (mem.ctrl.reg_wr = '1' and mem.rdst_adr /= b"00000" and mem.rdst_adr = exe.rs1_adr) then
            haz.exe_fw_rs1_sel <= MEM_FW;
        elsif (wrb.ctrl.reg_wr = '1' and wrb.rdst_adr /= b"00000" and wrb.rdst_adr = exe.rs1_adr) then
            haz.exe_fw_rs1_sel <= WRB_FW;
        else 
            haz.exe_fw_rs1_sel <= NO_FW;
        end if; 
        -- RS2
        if    (mem.ctrl.reg_wr = '1' and mem.rdst_adr /= b"00000" and mem.rdst_adr = exe.rs2_adr) then
            haz.exe_fw_rs2_sel <= MEM_FW;
        elsif (wrb.ctrl.reg_wr = '1' and wrb.rdst_adr /= b"00000" and wrb.rdst_adr = exe.rs2_adr) then
            haz.exe_fw_rs2_sel <= WRB_FW;
        else 
            haz.exe_fw_rs2_sel <= NO_FW;
        end if; 

        -- Forwarding to memory stage
        -- RS2 - Needed for memory access
        if    (wrb.ctrl.reg_wr = '1' and wrb.rdst_adr /= b"00000" and wrb.rdst_adr = mem.rs2_adr) then
            haz.mem_fw_rs2_sel <= WRB_FW;
        else 
            haz.mem_fw_rs2_sel <= NO_FW;
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
    haz.br_ld_hazard <= '1' when dec.ctrl.branch = '1' 
                             and mem.ctrl.mem_rd = '1' 
                             and mem.rdst_adr /= b"00000" 
                             and (mem.rdst_adr = dec.rs1_adr 
                              or mem.rdst_adr = dec.rs2_adr) 
                    else '0'; 

    haz.jalr_ld_hazard <= '1' when dec.ctrl.jalr = '1' 
                               and mem.ctrl.mem_rd = '1' 
                               and mem.rdst_adr /= b"00000" 
                               and mem.rdst_adr = dec.rs1_adr 
                    else '0'; 

    -- if branch is in ID while add,etc is in EX, wait till add,etc is in MEM
    haz.br_hazard <= '1' when dec.ctrl.branch = '1' 
                      and exe.ctrl.reg_wr = '1' 
                      and exe.rdst_adr /= b"00000" 
                      and (exe.rdst_adr = dec.rs1_adr 
                       or exe.rdst_adr = dec.rs2_adr) 
                    else '0';

    haz.jalr_hazard <= '1' when dec.ctrl.jalr = '1' 
                        and exe.ctrl.reg_wr = '1' 
                        and exe.rdst_adr /= b"00000" 
                        and (exe.rdst_adr = dec.rs1_adr) 
                    else '0';  

    -- If an mret instr follows an epc csr write, then we need to stall until the 
    -- epc is updated with the latest value (since mret causes an epc read)
    -- if rs1_adr /= b"00000" then we dont need to stall because the csr value is not 
    -- being modified
    haz.mret_hazard <= '1' when dec.mret = '1' 
                            and exe.csr_access = '1' 
                            and exe.rs1_adr /= b"00000"
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


        -- Turn a wfi instruction into a nop 
        -- TODO: Implementing wfi is low priority. Dont worry about this till
        -- everything else works. 
        if (dec.wfi) then 
            haz.exe_flush <= '1'; 
        end if; 
        
        -- Control Hazards -----------------------------------------------------
        -- kill the instruction that caused the trap after it has written its trap information during the exe stage
        -- This way, any illegal value that comes from an illegal instruction does not get writen back.
        -- We also don't want exception / interrupted instructions to increment the instruction 
        -- performance counter. 
        if (exe.any_trap) then 
            haz.mem_flush <= '1'; 
        end if; 

        -- Memory stage exceptions 
        -- Unlike decode stage exceptions, we go ahead and kill the bad memory exception
        -- here because it gets forwarded to the exe stage this cycle 
        -- For the decode stage excpetions, we wait until the instruction exits the exe 
        -- phase to kill it. 
        if (mem.load_adr_ma_excpt or mem.load_access_excpt or
                mem.store_adr_ma_excpt or mem.store_access_excpt) then
            haz.dec_flush <= '1';
            haz.exe_flush <= '1'; 
            haz.mem_flush <= '1';
            haz.exe_flush <= '1';
        end if;

        -- Decode stage exceptions, mret, and branch taken
        -- In these cases we want to flush the instruction that was speculatively 
        -- fetched after the exception instruction. The exception instruction will 
        -- also eventually get flushed, but not until after the exe stage where 
        -- the mcause csr is updated. The trap handler base address will be the next
        -- address fetched. So instruction order goes 
        -- 1. exception causing instruction 
        -- 2. speculatively fethed instruction (flushed)
        -- 3. trap handler base address instruction 
        if (dec.illeg_instr_excpt or dec.ecall_excpt or dec.ebreak_excpt or 
                    dec.mret or dec.fence or dec.fencei or dec.br_taken) then
            haz.dec_flush <= '1';
        end if; 


        -- Wait on Memory ------------------------------------------------------
        if (i_dstall) then -- pause the pipe while waiting on dmem
            haz.pc_enable  <= '0'; 
            haz.dec_enable <= '0';
            haz.exe_enable <= '0'; 
            haz.mem_enable <= '0';
            haz.wrb_flush  <= '1';
        end if; 

        if (i_istall) then -- pause the pipeline while waiting on the imem
            haz.pc_enable  <= '0'; 
            haz.dec_flush  <= '1'; 
        end if;


        -- Data Hazards --------------------------------------------------------
        if (haz.ld_hazard or haz.br_hazard or haz.jalr_hazard or haz.mret_hazard) then -- stall at dec, bubble at exe
            haz.pc_enable  <= '0'; 
            haz.dec_enable <= '0';
            haz.exe_flush  <= '1'; 
        end if; 
        
        if (haz.br_ld_hazard or haz.jalr_ld_hazard) then -- stall at dec, bubble at mem
            haz.pc_enable  <= '0'; 
            haz.dec_enable <= '0';
            haz.mem_flush  <= '1';
        end if; 
        
    end process;




    -- =========================================================================
    -- Performance Counters ====================================================
    -- =========================================================================
    -- Cycle Counter 
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            cnt.mcycle <= std_logic_vector(unsigned(exe.csr.mcycle) + 1);
        end if;
    end process;
    

    -- Instructions Retired Counter 
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (wrb.instret_incr) then
                cnt.minstret <= std_logic_vector(unsigned(exe.csr.minstret) + 1);
            end if; 
        end if;
    end process;

end architecture;


