-- #############################################################################
-- #  -<< RISC-V CPU >>-
-- # ===========================================================================
-- # Copyright 2022, David Gusser
-- # ===========================================================================
-- # File     : rv32_cpu.vhd
-- # Author   : David Gussler - david.gussler@proton.me
-- # Language : VHDL '08
-- # ===========================================================================
-- # 
-- #############################################################################

-- TODO: 
-- run tests with and without memory stalls 
-- add random instruction generator 
-- make sure there's a test for changing the mtvec
-- trial synthesis
-- change headers to my new email & bsd license
-- update memory module and connect 
-- synthesis 
-- start compiling real code and testing with that


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gen_utils_pkg.all;
use work.rv32_pkg.all;

entity rv32_cpu is
    generic (
        G_HART_ID    : std_logic_vector(31 downto 0) := x"0000_0000";
        G_RESET_ADDR : std_logic_vector(31 downto 0) := x"0000_0000"
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
        i_iack      : in  std_logic; 
        i_ierror    : in  std_logic;

        -- Data Interface 
        o_dren      : out std_logic;
        o_dwen      : out std_logic;
        o_dben      : out std_logic_vector(3 downto 0); -- byte enable 
        o_daddr     : out std_logic_vector(31 downto 0);
        o_dwdat     : out std_logic_vector(31 downto 0);
        o_fence     : out std_logic;
        i_drdat     : in  std_logic_vector(31 downto 0);
        i_dack      : in  std_logic; 
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
   signal pc : pc_t; --TODO: 
   signal f1 : f1_t;
   signal f2 : f2_t;
   signal id : id_t; 
   signal ex : ex_t;
   signal m1 : m1_t;  
   signal m2 : m2_t;  
   signal wb : wb_t;

   -- Hazard unit signals 
   signal hz : hz_t; 

   -- Performance counter signals
   signal ct : ct_t; 

begin
    --TODO: implement this when I add stalling on WFI instruction 
    o_sleep <= '0'; 
    
    -- TODO: Eventualy maybe add a debugger. This is low priority. 
    o_debug <= '0'; 

    -- =========================================================================
    -- Program Counter Stage ===================================================
    -- =========================================================================

    -- Handle Interrupts & Exceptions ------------------------------------------
    -- -------------------------------------------------------------------------
    -- Delay the interrupt pending bits by 1 so we can detect a rising edge 
    -- NOTE: The csr.mip bits are tied directly to the i_mX_irq input signals
    process (i_clk)
    begin
        if (rising_edge(i_clk)) then
            if (i_rst) then
                pc.dly_mip_msi <= '0';
                pc.dly_mip_mti <= '0';
                pc.dly_mip_mei <= '0';
            else
                pc.dly_mip_msi <= ex.csr.mip_msi;
                pc.dly_mip_mti <= ex.csr.mip_mti;
                pc.dly_mip_mei <= ex.csr.mip_mei;
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
    pc.trap.ms_irq <= (ex.csr.mip_msi and (not pc.dly_mip_msi or ex.mret)) and ex.csr.mie_msi and ex.csr.mstatus_mie; 
    pc.trap.mt_irq <= (ex.csr.mip_mti and (not pc.dly_mip_mti or ex.mret)) and ex.csr.mie_mti and ex.csr.mstatus_mie; 
    pc.trap.me_irq <= (ex.csr.mip_mei and (not pc.dly_mip_mei or ex.mret)) and ex.csr.mie_mei and ex.csr.mstatus_mie; 

    
    -- All Exceptions and Interrupts
    pc.trap_taken <= pc.trap.ms_irq or pc.trap.mt_irq or pc.trap.me_irq or 
                     m1.trap.load_adr_ma or m2.trap.load_access or 
                     m1.trap.store_adr_ma or m2.trap.store_access or 
                     ex.trap.illeg_instr or ex.trap.ecall or ex.trap.ebreak or 
                     ex.trap.instr_adr_ma or ex.trap.instr_access; 



    -- Forwarding Muxes
    -- TODO: Double-check risc V spec about weather or not to ignore the last two bits here
    ap_pc_fw_sel : process (all) 
    begin 
        -- Forwarding MEPC to PC stage. Needed since csrs are not written till wb stage
        if (ex.mret = '1' and m1.csr_access = '1' and m1.csr_adr = CSR_MEPC) then
            pc.pc_fw_mepc <= m1.csr_wdata(31 downto 2); 
        elsif (ex.mret = '1' and m2.csr_access = '1' and m2.csr_adr = CSR_MEPC) then
            pc.pc_fw_mepc <= m2.csr_wdata(31 downto 2); 
        elsif (ex.mret = '1' and wb.csr_access = '1' and wb.csr_adr = CSR_MEPC) then
            pc.pc_fw_mepc <= wb.csr_wdata(31 downto 2); 
        else 
            pc.pc_fw_mepc <= ex.csr.mtvec(31 downto 2);
        end if;


        -- Forwarding MTVEC to PC stage. Needed since csrs are not written till wb stage
        if (ex.any_trap = '1' and m1.csr_access = '1' and m1.csr_adr = CSR_MTVEC) then
            pc.pc_fw_mtvec <= m1.csr_wdata(31 downto 2); 
        elsif (ex.any_trap = '1' and m2.csr_access = '1' and m2.csr_adr = CSR_MTVEC) then
            pc.pc_fw_mtvec <= m2.csr_wdata(31 downto 2); 
        elsif (ex.any_trap = '1' and wb.csr_access = '1' and wb.csr_adr = CSR_MTVEC) then
            pc.pc_fw_mtvec <= wb.csr_wdata(31 downto 2); 
        else 
            pc.pc_fw_mtvec <= ex.csr.mtvec; 
        end if;
    end process; 

    

    -- Program Counter ------------------------------------------------
    -- -------------------------------------------------------------------------
    ap_pc : process (all) 
    begin
        if (ex.mret) then
            pc.pc <= pc.pc_fw_mepc(31 downto 2) & b"00"; 
        elsif (pc.trap_taken) then -- Must have higher priority than branch 
            pc.pc <= pc.pc_fw_mtvec(31 downto 2) & b"00";
        elsif (id.br_taken) then
            pc.pc <= id.brt_adr; 
        else 
            pc.pc <= std_logic_vector(unsigned(f1.pc) + 4);  
        end if;
    end process;
    
    
    sp_pc_f1_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst or hz.f1_flush) then
                f1.pc          <= G_RESET_ADDR(31 downto 2) & b"00";
                f1.trap.ms_irq <= '0';
                f1.trap.mt_irq <= '0';
                f1.trap.me_irq <= '0';
                --f1.iren        <= '1';
            elsif (hz.f1_enable) then
                f1.pc          <= pc.pc;
                f1.trap.ms_irq <= pc.trap.ms_irq;
                f1.trap.mt_irq <= pc.trap.mt_irq;
                f1.trap.me_irq <= pc.trap.me_irq;
                --f1.iren        <= '1';
            else 
                --f1.iren        <= '0'; -- Don't want to send repeat requests to memory on a stall
            end if;
        end if;
    end process;



    -- =========================================================================
    -- Fetch 1 Stage ===========================================================
    -- =========================================================================
    -- Instruction data request
    o_iren  <= f1.iren;
    o_iaddr <= f1.pc;

    f1.trap.instr_adr_ma <= (f1.pc(0) or f1.pc(1)) and o_iren;
    f1.iren <= hz.f2_enable;  

    sp_f1_f2_regs : process (i_clk)
    begin 
        if rising_edge(i_clk) then
            if (i_rst or hz.f2_flush) then
                f2.pc                <= (others=>'-');
                f2.trap.ms_irq       <= '0';
                f2.trap.mt_irq       <= '0';
                f2.trap.me_irq       <= '0';
                f2.trap.instr_adr_ma <= '0'; 
                f2.asdf              <= '0'; 
                f2.iren <= '0';
            elsif (hz.f2_enable) then
                f2.pc                <= f1.pc;
                f2.trap.ms_irq       <= f1.trap.ms_irq;
                f2.trap.mt_irq       <= f1.trap.mt_irq;
                f2.trap.me_irq       <= f1.trap.me_irq;
                f2.trap.instr_adr_ma <= f1.trap.instr_adr_ma; 
                f2.asdf              <= '1'; 
                f2.iren <= f1.iren;
            end if;
        end if;
    end process;

    -- From F2's perspective, F1 is always inititiating a mem request after reset. 
    -- only used for determining memory stalls
    -- sp_f2_iren : process (i_clk)
    -- begin
    --     if rising_edge(i_clk) then
    --         if (i_rst) then
    --             f2.iren <= '0';
    --         elsif (f1.iren) then
    --             f2.iren <= '1'; 
    --         end if;             
    --     end if;
    -- end process;

    -- Used for flushing the f2 valid signal. needed because this valid sig 
    -- is not known till f2 stage. 
    -- sp_f2_flush_dly1 : process (i_clk)
    -- begin
    --     if rising_edge(i_clk) then
    --         if (i_rst) then
    --             f2.flush_dly1 <= '0';
    --         elsif (hz.f2_enable) then
    --             f2.flush_dly1 <= hz.f2_flush; 
    --         end if;         
    --     end if;
    -- end process;


    -- =========================================================================
    -- Fetch 2 Stage ===========================================================
    -- =========================================================================
    -- Instruction data response 
    -- This is when we find out if there was a bad or stalled memory access
    
    ap_asdfasdf1 : process (i_clk)
    begin
        if rising_edge(i_clk) then 
            if (i_iack and not hz.f2_enable) then
                f2.i_ierror_reg <= i_ierror;
                f2.i_iack_reg <= i_iack;
                f2.i_irdat_reg <= i_irdat; 
            end if; 
        end if;
    end process;

    ap_asdfasdf : process (all)
    begin
        if (hz.f2_enable) then
            f2.trap.instr_access <= f2.iren and i_ierror; 
            f2.valid <= i_iack and f2.asdf; 
            f2.instr <= i_irdat; 
        else 
            f2.trap.instr_access <= f2.iren and f2.i_ierror_reg; 
            f2.valid <= f2.i_iack_reg and f2.asdf; 
            f2.instr <= f2.i_irdat_reg;
        end if;
    end process;

    sp_f2_id_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst or hz.id_flush or not f2.valid) then
                id.pc                <= (others=>'-'); 
                id.valid             <= '0'; 
                id.trap.ms_irq       <= '0'; 
                id.trap.mt_irq       <= '0'; 
                id.trap.me_irq       <= '0'; 
                id.trap.instr_adr_ma <= '0'; 
                id.trap.instr_access <= '0'; 
                id.instr             <= (others=>'-'); 
            elsif (hz.id_enable) then
                id.pc                <= f2.pc;          
                id.valid             <= f2.valid;           
                id.trap.ms_irq       <= f2.trap.ms_irq;       
                id.trap.mt_irq       <= f2.trap.mt_irq;       
                id.trap.me_irq       <= f2.trap.me_irq;       
                id.trap.instr_adr_ma <= f2.trap.instr_adr_ma; 
                id.trap.instr_access <= f2.trap.instr_access; 
                id.instr             <= f2.instr; 
            end if;
        end if;
    end process;

    -- =========================================================================
    -- Decode Stage ============================================================
    -- =========================================================================
    id.opcode   <= id.instr(RANGE_OPCODE);
    id.rs1_adr  <= id.instr(RANGE_RS1);
    id.rs2_adr  <= id.instr(RANGE_RS2);
    id.rdst_adr <= id.instr(RANGE_RD);
    id.funct3   <= id.instr(RANGE_FUNCT3);
    id.funct7   <= id.instr(RANGE_FUNCT7);


    -- Register File -----------------------------------------------------------
    -- -------------------------------------------------------------------------
    -- Sync Writes
    sp_regfile_write : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if wb.ctrl.reg_wr = '1' and wb.rdst_adr /= b"00000" then
                id.regfile(to_integer(unsigned(wb.rdst_adr))) <= wb.rdst_dat; 
            end if; 
        end if;
    end process;

    -- Async Reads. Needs to be async so I can handle branch resolution in dec stage.
    ap_regfile_read : process (all)
    begin
        if id.rs1_adr = b"00000" then
            id.rs1_dat <= (others=>'0');
        else
            id.rs1_dat <= id.regfile(to_integer(unsigned(id.rs1_adr)));
        end if;

        if id.rs2_adr = b"00000" then
            id.rs2_dat <= (others=>'0');
        else
            id.rs2_dat <= id.regfile(to_integer(unsigned(id.rs2_adr)));
        end if;
    end process;


    -- Control Unit ------------------------------------------------------------
    -- -------------------------------------------------------------------------
    ap_ctrl : process (all)
    begin
        case (id.opcode) is
            when OPCODE_LUI => 
                id.ctrl.reg_wr   <= '1';
                id.ctrl.wrb_sel  <= WRB_SEL_EXE;
                id.ctrl.mem_wr   <= '0';
                id.ctrl.mem_rd   <= '0'; 
                id.ctrl.alu_ctrl <= ALU_CTRL_ADD; 
                id.ctrl.alua_sel <= ALU_A_ZERO;
                id.ctrl.alub_sel <= ALU_B_IMM32;
                id.ctrl.jal      <= '0';
                id.ctrl.jalr     <= '0';
                id.ctrl.branch   <= '0';
                id.ctrl.imm_type <= UTYPE;
                id.ctrl.sys      <= '0'; 
                id.ctrl.fence    <= '0';
                id.ctrl.illegal  <= '0'; 
    
            when OPCODE_AUIPC => 
                id.ctrl.reg_wr   <= '1';
                id.ctrl.wrb_sel  <= WRB_SEL_EXE;
                id.ctrl.mem_wr   <= '0';
                id.ctrl.mem_rd   <= '0';
                id.ctrl.alu_ctrl <= ALU_CTRL_ADD; 
                id.ctrl.alua_sel <= ALU_A_PC;
                id.ctrl.alub_sel <= ALU_B_IMM32;
                id.ctrl.jal      <= '0';
                id.ctrl.jalr     <= '0';
                id.ctrl.branch   <= '0';
                id.ctrl.imm_type <= UTYPE;
                id.ctrl.sys      <= '0'; 
                id.ctrl.fence    <= '0';
                id.ctrl.illegal  <= '0'; 
    
            when OPCODE_ALUI  =>
                id.ctrl.reg_wr   <= '1';
                id.ctrl.wrb_sel  <= WRB_SEL_EXE;
                id.ctrl.mem_wr   <= '0';
                id.ctrl.mem_rd   <= '0';
                id.ctrl.alu_ctrl <= ALU_CTRL_ALU;
                id.ctrl.alua_sel <= ALU_A_RS1;
                id.ctrl.alub_sel <= ALU_B_IMM32;
                id.ctrl.jal      <= '0';
                id.ctrl.jalr     <= '0';
                id.ctrl.branch   <= '0';
                id.ctrl.imm_type <= ITYPE;
                id.ctrl.sys      <= '0'; 
                id.ctrl.fence    <= '0';
                id.ctrl.illegal  <= '0'; 
    
            when OPCODE_ALUR  =>
                id.ctrl.reg_wr   <= '1';
                id.ctrl.wrb_sel  <= WRB_SEL_EXE;
                id.ctrl.mem_wr   <= '0';
                id.ctrl.mem_rd   <= '0';
                id.ctrl.alu_ctrl <= ALU_CTRL_ALU;
                id.ctrl.alua_sel <= ALU_A_RS1;
                id.ctrl.alub_sel <= ALU_B_RS2;
                id.ctrl.jal      <= '0';
                id.ctrl.jalr     <= '0';
                id.ctrl.branch   <= '0';
                id.ctrl.imm_type <= RTYPE;
                id.ctrl.sys      <= '0'; 
                id.ctrl.fence    <= '0';
                id.ctrl.illegal  <= '0'; 
    
            when OPCODE_JAL  =>  
                id.ctrl.reg_wr   <= '1';
                id.ctrl.wrb_sel  <= WRB_SEL_PC4; 
                id.ctrl.mem_wr   <= '0';
                id.ctrl.mem_rd   <= '0';
                id.ctrl.alu_ctrl <= '-';  
                id.ctrl.alua_sel <= b"--";   
                id.ctrl.alub_sel <= '-'; 
                id.ctrl.jal      <= '1';
                id.ctrl.jalr     <= '0';
                id.ctrl.branch   <= '0';
                id.ctrl.imm_type <= JTYPE;
                id.ctrl.sys      <= '0'; 
                id.ctrl.fence    <= '0';
                id.ctrl.illegal  <= '0'; 
    
            when OPCODE_JALR =>  
                id.ctrl.reg_wr   <= '1';
                id.ctrl.wrb_sel  <= WRB_SEL_PC4; 
                id.ctrl.mem_wr   <= '0';
                id.ctrl.mem_rd   <= '0';
                id.ctrl.alu_ctrl <= '-';  
                id.ctrl.alua_sel <= b"--";  
                id.ctrl.alub_sel <= '-'; 
                id.ctrl.jal      <= '0';
                id.ctrl.jalr     <= '1';
                id.ctrl.branch   <= '0';
                id.ctrl.imm_type <= ITYPE;
                id.ctrl.sys      <= '0'; 
                id.ctrl.fence    <= '0';
                id.ctrl.illegal  <= '0'; 
    
            when OPCODE_BRANCH =>
                id.ctrl.reg_wr   <= '0';
                id.ctrl.wrb_sel  <= b"--";
                id.ctrl.mem_wr   <= '0';
                id.ctrl.mem_rd   <= '0';
                id.ctrl.alu_ctrl <= '-';  
                id.ctrl.alua_sel <= b"--";
                id.ctrl.alub_sel <= '-'; 
                id.ctrl.jal      <= '0';
                id.ctrl.jalr     <= '0';
                id.ctrl.branch   <= '1';
                id.ctrl.imm_type <= BTYPE;
                id.ctrl.sys      <= '0'; 
                id.ctrl.fence    <= '0';
                id.ctrl.illegal  <= '0'; 
    
            when OPCODE_LOAD =>
                id.ctrl.reg_wr   <= '1';
                id.ctrl.wrb_sel  <= WRB_SEL_MEM;
                id.ctrl.mem_wr   <= '0';
                id.ctrl.mem_rd   <= '1';
                id.ctrl.alu_ctrl <= ALU_CTRL_ADD;
                id.ctrl.alua_sel <= ALU_A_RS1;
                id.ctrl.alub_sel <= ALU_B_IMM32;
                id.ctrl.jal      <= '0';
                id.ctrl.jalr     <= '0';
                id.ctrl.branch   <= '0';
                id.ctrl.imm_type <= ITYPE;
                id.ctrl.sys      <= '0'; 
                id.ctrl.fence    <= '0';
                id.ctrl.illegal  <= '0'; 
    
            when OPCODE_STORE =>
                id.ctrl.reg_wr   <= '0';
                id.ctrl.wrb_sel  <= b"--";
                id.ctrl.mem_wr   <= '1';
                id.ctrl.mem_rd   <= '0';
                id.ctrl.alu_ctrl <= ALU_CTRL_ADD;
                id.ctrl.alua_sel <= ALU_A_RS1;
                id.ctrl.alub_sel <= ALU_B_IMM32;
                id.ctrl.jal      <= '0';
                id.ctrl.jalr     <= '0';
                id.ctrl.branch   <= '0';
                id.ctrl.imm_type <= STYPE; 
                id.ctrl.sys      <= '0'; 
                id.ctrl.fence    <= '0';
                id.ctrl.illegal  <= '0'; 
    
            when OPCODE_FENCE =>
                id.ctrl.reg_wr   <= '0';
                id.ctrl.wrb_sel  <= b"--";
                id.ctrl.mem_wr   <= '0';
                id.ctrl.mem_rd   <= '0';
                id.ctrl.alu_ctrl <= '-';  
                id.ctrl.alua_sel <= b"--";
                id.ctrl.alub_sel <= '-'; 
                id.ctrl.jal      <= '0';
                id.ctrl.jalr     <= '0';
                id.ctrl.branch   <= '0';
                id.ctrl.imm_type <= b"---"; 
                id.ctrl.sys      <= '0'; 
                id.ctrl.fence    <= '1';
                id.ctrl.illegal  <= '0'; 
    
            -- NOTE: csr, ecall, ebreak, mret, and wfi instructions. 
            -- only csr uses reg wr = '1', but its okay that this is set to 1 for the other
            -- instructions because they have their rs1 and rdst fields set to 0, meaning 
            -- that no write will actually happen and forwarding will not get triggered.
            when OPCODE_SYSTEM =>
                id.ctrl.reg_wr   <= '1';
                id.ctrl.wrb_sel  <= WRB_SEL_EXE;
                id.ctrl.mem_wr   <= '0';
                id.ctrl.mem_rd   <= '0';
                id.ctrl.alu_ctrl <= '-';  
                id.ctrl.alua_sel <= b"--";
                id.ctrl.alub_sel <= '-'; 
                id.ctrl.jal      <= '0';
                id.ctrl.jalr     <= '0';
                id.ctrl.branch   <= '0';
                id.ctrl.imm_type <= ITYPE; 
                id.ctrl.sys      <= '1'; 
                id.ctrl.fence    <= '0';
                id.ctrl.illegal  <= '0'; 
    
            when others =>
                id.ctrl.reg_wr   <= '0';
                id.ctrl.wrb_sel  <= b"--";
                id.ctrl.mem_wr   <= '0';
                id.ctrl.mem_rd   <= '0';
                id.ctrl.alu_ctrl <= '-';  
                id.ctrl.alua_sel <= b"--";
                id.ctrl.alub_sel <= '-'; 
                id.ctrl.jal      <= '0';
                id.ctrl.jalr     <= '0';
                id.ctrl.branch   <= '0';
                id.ctrl.imm_type <= b"---"; 
                id.ctrl.sys      <= '0'; 
                id.ctrl.fence    <= '0';
                id.ctrl.illegal  <= '1'; 
        end case; 
    end process;

    -- Illegal instruction exception
    id.trap.illeg_instr <= id.ctrl.illegal and id.valid; -- TODO: consider removing and valid
 

    -- Construct the 32-bit signed immediate
    -- NOTE: could add another decode stage to process this since it happens after opcode decoder
    ap_imm32 : process (all) 
    begin
        case (id.ctrl.imm_type) is
            when (STYPE) => 
                id.imm32(31 downto 12) <= (others=>id.instr(31));
                id.imm32(11 downto 5)  <= id.instr(RANGE_IMM_S_11_5);
                id.imm32(4 downto 0)   <= id.instr(RANGE_IMM_S_4_0);

            when (BTYPE) => 
                id.imm32(31 downto 13) <= (others=>id.instr(31));
                id.imm32(12)           <= id.instr(RANGE_IMM_B_12);
                id.imm32(11)           <= id.instr(RANGE_IMM_B_11);
                id.imm32(10 downto 5)  <= id.instr(RANGE_IMM_B_10_5);
                id.imm32(4 downto 1)   <= id.instr(RANGE_IMM_B_4_1);
                id.imm32(0)            <= '0';

            when (UTYPE) => 
                id.imm32(31 downto 12) <= id.instr(RANGE_IMM_U);
                id.imm32(11 downto 0)  <= X"000";

            when (JTYPE) => 
                id.imm32(31 downto 21) <= (others=>id.instr(31));
                id.imm32(20)           <= id.instr(RANGE_IMM_J_20);
                id.imm32(19 downto 12) <= id.instr(RANGE_IMM_J_19_12);
                id.imm32(11)           <= id.instr(RANGE_IMM_J_11);
                id.imm32(10 downto 1)  <= id.instr(RANGE_IMM_J_10_1);
                id.imm32(0)            <= '0';
            
            when others  => -- ITYPE
                id.imm32(31 downto 12) <= (others=>id.instr(31));
                id.imm32(11 downto 0)  <= id.instr(RANGE_IMM_I);

       end case; 
    end process; 


    -- Forwarding Muxes
    ap_dec_fw_sel : process (all) 
    begin 
        if (m1.ctrl.reg_wr = '1' and m1.rdst_adr /= b"00000" and m1.rdst_adr = id.rs1_adr) then
            id.id_fw_rs1_dat <= m1.exe_rslt;
        elsif (m2.ctrl.reg_wr = '1' and m2.rdst_adr /= b"00000" and m2.rdst_adr = id.rs1_adr) then
            id.id_fw_rs1_dat <= m2.exe_rslt;
        elsif (wb.ctrl.reg_wr = '1' and wb.rdst_adr /= b"00000" and wb.rdst_adr = id.rs1_adr) then
            id.id_fw_rs1_dat <= wb.rdst_dat;
        else 
            id.id_fw_rs1_dat <= id.rs1_dat;
        end if; 

        if (m1.ctrl.reg_wr = '1' and m1.rdst_adr /= b"00000" and m1.rdst_adr = id.rs2_adr) then
            id.id_fw_rs2_dat <= m1.exe_rslt;
        elsif (m2.ctrl.reg_wr = '1' and m2.rdst_adr /= b"00000" and m2.rdst_adr = id.rs2_adr) then
            id.id_fw_rs2_dat <= m2.exe_rslt;
        elsif (wb.ctrl.reg_wr = '1' and wb.rdst_adr /= b"00000" and wb.rdst_adr = id.rs2_adr) then
            id.id_fw_rs2_dat <= wb.rdst_dat;
        else 
            id.id_fw_rs2_dat <= id.rs2_dat;
        end if; 
    end process; 


    


    -- determine if a branch was taken and calculate the target address for 
    -- branches and jumps. Jumps (JAL, JALR) will always be taken 
    -- Adding the extra hardware to resolve branch in this stage rather than
    -- alu stage to save a stall cycle on mispredicted branches. Using a simple
    -- predict not taken scheme. 
    -- This probably adds to the crit path. Consider moving this to a later stage.
    -- Its a mispredict penalty vs clockspeed tradeoff. 
    ap_branch_resolution : process(all)
        variable v_brt_adr : std_logic_vector(31 downto 0);
    begin

        id.br_eq  <= '1' when id.id_fw_rs1_dat = id.id_fw_rs2_dat else '0'; 
        id.br_ltu <= '1' when unsigned(id.id_fw_rs1_dat) < unsigned(id.id_fw_rs2_dat) else '0'; 
        id.br_lt  <= '1' when signed(id.id_fw_rs1_dat) < signed(id.id_fw_rs2_dat) else '0'; 

        case (id.funct3) is 
            when F3_BEQ  => id.branch <=     id.br_eq; 
            when F3_BNE  => id.branch <= not id.br_eq; 
            when F3_BLT  => id.branch <=     id.br_lt;
            when F3_BGE  => id.branch <= not id.br_lt;
            when F3_BLTU => id.branch <=     id.br_ltu;
            when F3_BGEU => id.branch <= not id.br_ltu;
            when others  => id.branch <= '0';
        end case; 
      

        -- Control signal indicating that a branch, jal, or jalr has been taken
        id.br_taken <= id.ctrl.jal or id.ctrl.jalr or (id.ctrl.branch and id.branch);

        -- Branch, jal, or jalr target address
        if id.ctrl.jalr then
            v_brt_adr := std_logic_vector(signed(id.imm32) + signed(id.id_fw_rs1_dat)); 
            v_brt_adr := v_brt_adr(31 downto 1) & '0';
        else
            v_brt_adr :=  std_logic_vector(signed(id.imm32) + signed(id.pc)); 
        end if;   

        id.brt_adr <= v_brt_adr; 

    end process;


    -- System Instructions -----------------------------------------------------
    -- -------------------------------------------------------------------------
    ap_system : process (all)
    begin
        id.trap.ecall  <= '0'; 
        id.trap.ebreak <= '0'; 
        id.mret        <= '0';
        id.wfi         <= '0';
        id.csr_access  <= '0'; 

        if (id.ctrl.sys) then
            if (id.funct3 = F3_ENV) then
                case (id.imm32(11 downto 0)) is 
                    when F12_ECALL  => id.trap.ecall  <= '1'; 
                    when F12_EBREAK => id.trap.ebreak <= '1'; 
                    when F12_MRET   => id.mret        <= '1';
                    when F12_WFI    => id.wfi         <= '1';
                    when others     => null;
                end case; 
            else 
                id.csr_access <= '1'; 
            end if;
        end if; 
    end process;

    -- Fence Instructions ------------------------------------------------------
    -- -------------------------------------------------------------------------
    id.fence  <= '1' when id.ctrl.fence = '1' and id.funct3 = F3_FENCE  else '0'; 
    id.fencei <= '1' when id.ctrl.fence = '1' and id.funct3 = F3_FENCEI else '0';
    o_fence   <= id.fence;  
    o_fencei  <= id.fencei;


    -- =========================================================================
    -- Decode/Execute Registers ================================================
    -- =========================================================================
    sp_id_ex_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            -- We also explicitly flush this stage on the next cycle after last stage was flushed 
            -- this is necessary because the control signals generated in the decode 
            -- stage cannot be flushed the same cycle they are created. 
            if (i_rst or hz.ex_flush or not id.valid) then
                ex.pc                <= (others=>'-'); 
                ex.valid             <= '0'; 
                ex.trap.ms_irq       <= '0';
                ex.trap.mt_irq       <= '0';
                ex.trap.me_irq       <= '0';
                ex.trap.instr_adr_ma <= '0';
                ex.trap.instr_access <= '0';
                ex.trap.illeg_instr  <= '0';
                ex.trap.ecall        <= '0';
                ex.trap.ebreak       <= '0';
                ex.ctrl.reg_wr       <= '0'; 
                ex.ctrl.wrb_sel      <= (others=>'-');
                ex.ctrl.mem_wr       <= '0'; 
                ex.ctrl.mem_rd       <= '0'; 
                ex.ctrl.alu_ctrl     <= '-';
                ex.ctrl.alua_sel     <= (others=>'-');
                ex.ctrl.alub_sel     <= '-';
                ex.csr_access        <= '0';
                ex.rs1_adr           <= (others=>'-');
                ex.rs2_adr           <= (others=>'-');
                ex.rdst_adr          <= (others=>'-');
                ex.rs1_dat           <= (others=>'-');
                ex.rs2_dat           <= (others=>'-');
                ex.imm32             <= (others=>'-');
                ex.funct3            <= (others=>'-');
                ex.funct7            <= (others=>'-');
                ex.is_rtype          <= '-';
                ex.mret <= '0';
                ex.wfi  <= '0';
            elsif (hz.ex_enable) then
                ex.pc                 <= id.pc;
                ex.valid              <= id.valid; 
                ex.trap.ms_irq        <= id.trap.ms_irq      ;
                ex.trap.mt_irq        <= id.trap.mt_irq      ;
                ex.trap.me_irq        <= id.trap.me_irq      ;
                ex.trap.instr_adr_ma  <= id.trap.instr_adr_ma;
                ex.trap.instr_access  <= id.trap.instr_access;
                ex.trap.illeg_instr   <= id.trap.illeg_instr ;
                ex.trap.ecall         <= id.trap.ecall       ;
                ex.trap.ebreak        <= id.trap.ebreak      ;
                ex.ctrl.reg_wr        <= id.ctrl.reg_wr;
                ex.ctrl.wrb_sel       <= id.ctrl.wrb_sel;
                ex.ctrl.mem_wr        <= id.ctrl.mem_wr;
                ex.ctrl.mem_rd        <= id.ctrl.mem_rd;
                ex.ctrl.alu_ctrl      <= id.ctrl.alu_ctrl;
                ex.ctrl.alua_sel      <= id.ctrl.alua_sel;
                ex.ctrl.alub_sel      <= id.ctrl.alub_sel;
                ex.csr_access         <= id.csr_access;
                ex.rs1_adr            <= id.rs1_adr;
                ex.rs2_adr            <= id.rs2_adr;
                ex.rdst_adr           <= id.rdst_adr;
                ex.rs1_dat            <= id.id_fw_rs1_dat;
                ex.rs2_dat            <= id.id_fw_rs2_dat;
                ex.imm32              <= id.imm32; 
                ex.funct3             <= id.funct3;
                ex.funct7             <= id.funct7;
                ex.mret               <= id.mret; 
                -- Is this an R-Type instruction? Used for making alu opcode.
                ex.is_rtype <= '1' when id.ctrl.imm_type = RTYPE else '0';
                ex.mret <= id.mret;
                ex.wfi  <= id.wfi;
            end if; 
        end if;
    end process;

    -- =========================================================================
    -- Execute Stage ===========================================================
    -- =========================================================================
   
    -- Forwarding Muxes
    ap_ex_fw_sel : process (all) 
    begin 

        if    (m1.ctrl.reg_wr = '1' and m1.rdst_adr /= b"00000" and m1.rdst_adr = ex.rs1_adr) then
            ex.ex_fw_rs1_dat <= m1.exe_rslt;
        elsif (m2.ctrl.reg_wr = '1' and m2.rdst_adr /= b"00000" and m2.rdst_adr = ex.rs1_adr) then
            ex.ex_fw_rs1_dat <= m2.exe_rslt;
        elsif (wb.ctrl.reg_wr = '1' and wb.rdst_adr /= b"00000" and wb.rdst_adr = ex.rs1_adr) then
            ex.ex_fw_rs1_dat <= wb.rdst_dat;
        else 
            ex.ex_fw_rs1_dat <= ex.rs1_dat;
        end if; 

        if    (m1.ctrl.reg_wr = '1' and m1.rdst_adr /= b"00000" and m1.rdst_adr = ex.rs2_adr) then
            ex.ex_fw_rs2_dat <= m1.exe_rslt;
        elsif (m2.ctrl.reg_wr = '1' and m2.rdst_adr /= b"00000" and m2.rdst_adr = ex.rs2_adr) then
            ex.ex_fw_rs2_dat <= m2.exe_rslt;
        elsif (wb.ctrl.reg_wr = '1' and wb.rdst_adr /= b"00000" and wb.rdst_adr = ex.rs2_adr) then
            ex.ex_fw_rs2_dat <= wb.rdst_dat;
        else 
            ex.ex_fw_rs2_dat <= ex.rs2_dat;
        end if; 

    end process; 

    -- Integer ALU -------------------------------------------------------------
    -- -------------------------------------------------------------------------
    ap_int_alu: process (all) 
    begin 
        -- Select the first ALU operand
        case (ex.ctrl.alua_sel) is 
            when ALU_A_RS1     => ex.alua_dat <= ex.ex_fw_rs1_dat; 
            when ALU_A_PC      => ex.alua_dat <= ex.pc; 
            when ALU_A_ZERO    => ex.alua_dat <= (others=>'0'); 
            when others        => ex.alua_dat <= (others=>'-'); 
        end case; 

        -- Select the second ALU operand
        case (ex.ctrl.alub_sel) is 
            when ALU_B_RS2   => ex.alub_dat <= ex.ex_fw_rs2_dat; 
            when ALU_B_IMM32 => ex.alub_dat <= ex.imm32; 
            when others      => ex.alub_dat <= (others=>'-'); 
        end case;

        -- Build the aluop TODO: TODO: Experiment with adding this to decode stage to balance stage work 
        case (ex.ctrl.alu_ctrl) is 
            when ALU_CTRL_ADD => 
                ex.aluop <= ALUOP_ADD;  

            when ALU_CTRL_ALU => 
                case (ex.funct3) is
                    when F3_SUBADD =>
                        if (ex.is_rtype and ex.funct7(5)) then
                            ex.aluop <= ALUOP_SUB;
                        else
                            ex.aluop <= ALUOP_ADD;
                        end if;

                    when F3_SR =>
                        if (ex.funct7(5)) then
                            ex.aluop <= ALUOP_SRA;
                        else
                            ex.aluop <= ALUOP_SRL;
                        end if; 

                    when F3_SLL => ex.aluop <= ALUOP_SLL ;
                    when F3_SLT => ex.aluop <= ALUOP_SLT ;  
                    when F3_SLTU=> ex.aluop <= ALUOP_SLTU;  
                    when F3_XOR => ex.aluop <= ALUOP_XOR ;   
                    when F3_OR  => ex.aluop <= ALUOP_OR  ; 
                    when F3_AND => ex.aluop <= ALUOP_AND ; 
                    when others => ex.aluop <= (others=>'-'); 
                end case;
            when others => ex.aluop <= (others=>'-'); 
        end case; 

        -- ALU
        case (ex.aluop) is
            when ALUOP_ADD  => ex.alu_rslt <= 
                std_logic_vector(signed(ex.alua_dat) + signed(ex.alub_dat)); 

            when ALUOP_SUB  => ex.alu_rslt <= 
                std_logic_vector(signed(ex.alua_dat) - signed(ex.alub_dat));

            when ALUOP_SLL  => ex.alu_rslt <= 
                std_logic_vector(shift_left(unsigned(ex.alua_dat), 
                to_integer(unsigned(ex.alub_dat(4 downto 0)))));

            when ALUOP_SLT  => ex.alu_rslt <= 
                x"0000_0001" when (signed(ex.alua_dat) < signed(ex.alub_dat))  
                else x"0000_0000"; 

            when ALUOP_SLTU => ex.alu_rslt <=
                x"0000_0001" when (unsigned(ex.alua_dat) < unsigned(ex.alub_dat)) 
                else x"0000_0000"; 

            when ALUOP_XOR  => ex.alu_rslt <= 
                ex.alua_dat xor ex.alub_dat; 

            when ALUOP_SRL  => ex.alu_rslt <= 
                std_logic_vector(shift_right(unsigned(ex.alua_dat), 
                to_integer(unsigned(ex.alub_dat(4 downto 0)))));    

            when ALUOP_SRA  => ex.alu_rslt <= 
                std_logic_vector(shift_right(signed(ex.alua_dat),
                to_integer(unsigned(ex.alub_dat(4 downto 0)))));

            when ALUOP_OR   => ex.alu_rslt <= 
                ex.alua_dat or ex.alub_dat; 

            when ALUOP_AND  => ex.alu_rslt <= 
                ex.alua_dat and ex.alub_dat; 
                
            when others     => ex.alu_rslt <= 
                (others=>'-');
        end case; 
    end process; 
 
   
    -- CSR Access --------------------------------------------------------------
    -- -------------------------------------------------------------------------

    ex.csr_adr <= ex.imm32(11 downto 0); 

    -- Forwarding Mux
    -- Need to forward the modified csr data because the csrs dont get written
    -- by software till the wb stage. So the is the "effective" csr read data.
    -- What would ahve been read assuming the preceding csr instr has updated the 
    -- register already 
    ap_ex_csr_fw_sel : process (all) 
    begin 
        if (ex.csr_access = '1' and m1.csr_access = '1' and ex.csr_adr = m1.csr_adr) then
            ex.ex_fw_csr_rdat <= m1.csr_wdata;
        elsif (ex.csr_access = '1' and m2.csr_access = '1' and ex.csr_adr = m2.csr_adr) then
            ex.ex_fw_csr_rdat <= m2.csr_wdata;
        elsif (ex.csr_access = '1' and wb.csr_access = '1' and ex.csr_adr = wb.csr_adr) then
            ex.ex_fw_csr_rdat <= wb.csr_wdata;
        else 
            ex.ex_fw_csr_rdat <= ex.csr_rdata;
        end if; 
    end process; 


    -- Generate the csr write data (for SW writes)
    ap_csr_wdata : process (all)
    begin
        case ex.funct3 is 
            when F3_CSRRW =>  
                ex.csr_wdata <= ex.ex_fw_rs1_dat;

            when F3_CSRRS =>
                ex.csr_wdata <= ex.ex_fw_rs1_dat or ex.ex_fw_csr_rdat;

            when F3_CSRRC =>
                ex.csr_wdata <= not ex.ex_fw_rs1_dat and ex.ex_fw_csr_rdat;

            when F3_CSRRWI =>  
                ex.csr_wdata(31 downto 5) <= (others=>'0');
                ex.csr_wdata(4 downto 0)  <= ex.rs1_adr;

            when F3_CSRRSI =>
                ex.csr_wdata(31 downto 5) <= ex.ex_fw_csr_rdat(31 downto 5);
                ex.csr_wdata(4 downto 0)  <= ex.rs1_adr or ex.ex_fw_csr_rdat(4 downto 0);

            when F3_CSRRCI =>
                ex.csr_wdata(31 downto 5) <= (others=>'0');
                ex.csr_wdata(4 downto 0)  <= not ex.rs1_adr and ex.ex_fw_csr_rdat(4 downto 0);

            when others    => 
                ex.csr_wdata <= (others=>'-');
        end case; 
    end process;


    ex.any_trap <= ex.trap.ms_irq or ex.trap.mt_irq or ex.trap.me_irq or 
                     m1.trap.load_adr_ma or m2.trap.load_access or 
                     m1.trap.store_adr_ma or m2.trap.store_access or 
                     ex.trap.illeg_instr or ex.trap.ecall or ex.trap.ebreak or 
                     ex.trap.instr_adr_ma or ex.trap.instr_access; 


    -- Writes
    sp_csr_wr : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst) then
                -- These are the only CSRs that need to be reset to a specific value
                -- All others are undefined according to the spec. This means that 
                -- SW should initialize the undefined CSRs
                ex.csr.mstatus_mie  <= '0';
                ex.csr.mcause_intr  <= '0';
                ex.csr.mcause_code  <= (others=>'0');

                -- These CSRs are not required to be reset by hardware
                -- Im initializing some of them anyways for convenience
                ex.csr.mstatus_mpie <= '0';
                ex.csr.mie_msi      <= '0';
                ex.csr.mie_mti      <= '0';
                ex.csr.mie_mei      <= '0';
                ex.csr.mip_msi      <= '0';
                ex.csr.mip_mti      <= '0';
                ex.csr.mip_mei      <= '0';
                ex.csr.mepc         <= (others=>'-');
                ex.csr.mcycle       <= (others=>'0');
                ex.csr.minstret     <= (others=>'0');

            -- SW Writes take priority over HW if both try to write on the same cycle
            else 

                -- HW writes by CPU
                -- 
                -- TODO: add these with FP extension 
                --ex.csr.fflags      <= ; 
                --ex.csr.frm         <= ; 
                --ex.csr.fcsr        <= ; 
                --ex.csr.mstatus(FS) <= ; 
                --ex.csr.mstatus(SD) <= ; 
                
                ex.csr.mip_msi <= i_ms_irq;
                ex.csr.mip_mti <= i_me_irq;
                ex.csr.mip_mei <= i_mt_irq;

                ex.csr.mcycle   <= ct.mcycle; 
                ex.csr.minstret <= ct.minstret; 

                -- Restore IE status on a mret 
                if (ex.mret) then
                    ex.csr.mstatus_mie     <= ex.csr.mstatus_mpie;
                end if;  

                -- Set Previous IE status on a trap 
                if (ex.any_trap) then
                    ex.csr.mstatus_mpie    <= ex.csr.mstatus_mie;
                end if;  
            

                -- Set the trap cause register and exception program counter
                -- registers
                -- NOTE: SW is expected to increment the epc to the next instruction 
                -- for an ecall/ebreak. If SW doesnt do this, then we'll get caught 
                -- in an ecall / irq handler / mret ... loop 
                -- NOTE: Notice that the memory stage epcs are forwarded
                -- Priority defined in risc V spec 
                if (ex.trap.me_irq) then
                    ex.csr.mcause_intr       <= '1'; 
                    ex.csr.mcause_code       <= TRAP_MEI_IRQ; --11
                    ex.csr.mepc(31 downto 2) <= ex.pc(31 downto 2);
                elsif (ex.trap.ms_irq) then 
                    ex.csr.mcause_intr       <= '1'; 
                    ex.csr.mcause_code       <= TRAP_MSI_IRQ; --3
                    ex.csr.mepc(31 downto 2) <= ex.pc(31 downto 2);
                elsif (ex.trap.mt_irq) then
                    ex.csr.mcause_intr      <= '1'; 
                    ex.csr.mcause_code      <= TRAP_MTI_IRQ; --7
                    ex.csr.mepc(31 downto 2) <= ex.pc(31 downto 2);
                elsif (ex.trap.instr_adr_ma) then
                    ex.csr.mcause_intr      <= '0'; 
                    ex.csr.mcause_code      <= TRAP_IMA; --0
                    ex.csr.mepc(31 downto 2) <= ex.pc(31 downto 2);
                elsif (ex.trap.instr_access) then
                    ex.csr.mcause_intr      <= '0'; 
                    ex.csr.mcause_code      <= TRAP_IACC; --1
                    ex.csr.mepc(31 downto 2) <= ex.pc(31 downto 2);
                elsif (ex.trap.illeg_instr) then
                    ex.csr.mcause_intr      <= '0'; 
                    ex.csr.mcause_code      <= TRAP_ILL_INTR; --2
                    ex.csr.mepc(31 downto 2) <= ex.pc(31 downto 2);
                elsif (ex.trap.ebreak) then
                    ex.csr.mcause_intr      <= '0'; 
                    ex.csr.mcause_code      <= TRAP_EBREAK; --3
                    ex.csr.mepc(31 downto 2) <= ex.pc(31 downto 2);
                elsif (m1.trap.load_adr_ma) then
                    ex.csr.mcause_intr      <= '0'; 
                    ex.csr.mcause_code      <= TRAP_LMA; --4
                    ex.csr.mepc(31 downto 2) <= m1.pc(31 downto 2);
                elsif (m2.trap.load_access) then
                    ex.csr.mcause_intr      <= '0'; 
                    ex.csr.mcause_code      <= TRAP_LACC; --5
                    ex.csr.mepc(31 downto 2) <= m2.pc(31 downto 2);
                elsif (m1.trap.store_adr_ma) then
                    ex.csr.mcause_intr      <= '0'; 
                    ex.csr.mcause_code      <= TRAP_SMA; --6
                    ex.csr.mepc(31 downto 2) <= m1.pc(31 downto 2);
                elsif (m2.trap.store_access) then
                    ex.csr.mcause_intr      <= '0'; 
                    ex.csr.mcause_code      <= TRAP_SACC; --7
                    ex.csr.mepc(31 downto 2) <= m2.pc(31 downto 2);
                elsif (ex.trap.ecall) then
                    ex.csr.mcause_intr      <= '0'; 
                    ex.csr.mcause_code      <= TRAP_MECALL; --11
                    ex.csr.mepc(31 downto 2) <= ex.pc(31 downto 2);
                end if; 


                -- SW Writes
                if (wb.csr_access) then
                    case (wb.csr_adr) is
                        --when CSR_FFLAGS  => TODO: 
                        --when CSR_FRM     =>
                        --when CSR_FCSR    =>

                        when CSR_MSTATUS =>
                            ex.csr.mstatus_mie  <= wb.csr_wdata(MIE); 
                            ex.csr.mstatus_mpie <= wb.csr_wdata(MPIE);
                        
                        when CSR_MIE =>
                            ex.csr.mie_msi <= wb.csr_wdata(MSI); 
                            ex.csr.mie_mti <= wb.csr_wdata(MTI); 
                            ex.csr.mie_mei <= wb.csr_wdata(MEI); 
                    
                        when CSR_MEPC =>
                            ex.csr.mepc(31 downto 2) <= wb.csr_wdata(31 downto 2);
                        
                        when CSR_MTVEC =>
                            ex.csr.mtvec(31 downto 2) <= wb.csr_wdata(31 downto 2); 
                        
                        when CSR_MCYCLE =>
                            ex.csr.mcycle   <= wb.csr_wdata; 
                            
                        when CSR_MINSTRET =>
                            ex.csr.minstret <= wb.csr_wdata; 

                        when others =>
                            null;
                    end case;   
                end if; 
            end if; 
        end if;
    end process;


    -- Reads
    ap_csr_rd : process(all)
    begin 

        ex.csr_rdata <= (others=>'0'); -- default

        if (ex.csr_access) then
            case (ex.csr_adr) is
                -- TODO: add these with FP extension
                --when CSR_FFLAGS  => ex.csr_rdata <= ex.csr.fflags; 
                --when CSR_FRM     => ex.csr_rdata <= ex.csr.frm   ;
                --when CSR_FCSR    => ex.csr_rdata <= ex.csr.fcsr  ;

                when CSR_TIME =>
                    ex.csr_rdata  <= i_mtime;
            
                when CSR_MHARTID =>
                    ex.csr_rdata  <= G_HART_ID;

                when CSR_MSTATUS =>
                    ex.csr_rdata(MIE)  <= ex.csr.mstatus_mie ;
                    ex.csr_rdata(MPIE) <= ex.csr.mstatus_mpie;
                    --ex.csr_rdata(FS)   <= ex.csr.mstatus(FS)  ; TODO: add these with FP extension
                    --ex.csr_rdata(SD)   <= ex.csr.mstatus(SD)  ; TODO: add these with FP extension
                
                when CSR_MTVEC =>
                    ex.csr_rdata(MODE) <= b"00"; -- Direct mode - All exceptions set PC to BASE
                    ex.csr_rdata(BASE) <= ex.csr.mtvec(31 downto 2); 

                when CSR_MIE =>
                    ex.csr_rdata(MSI) <= ex.csr.mie_msi; 
                    ex.csr_rdata(MTI) <= ex.csr.mie_mti; 
                    ex.csr_rdata(MEI) <= ex.csr.mie_mei; 

                when CSR_MIP =>
                    ex.csr_rdata(MSI) <= ex.csr.mip_msi; 
                    ex.csr_rdata(MTI) <= ex.csr.mip_mti; 
                    ex.csr_rdata(MEI) <= ex.csr.mip_mei; 

                when CSR_MCYCLE | CSR_CYCLE =>
                    ex.csr_rdata <= ex.csr.mcycle; 

                when CSR_MINSTRET | CSR_INSTRET =>
                    ex.csr_rdata <= ex.csr.minstret; 

                when CSR_MEPC =>
                    ex.csr_rdata(31 downto 2) <= ex.csr.mepc(31 downto 2);

                when CSR_MCAUSE =>
                    ex.csr_rdata(INTR) <= ex.csr.mcause_intr;
                    ex.csr_rdata(CODE) <= ex.csr.mcause_code;

                when others =>
                    null;
            end case;
        end if;
    end process; 

    -- Execute stage result mux
    ex.exe_rslt <= ex.ex_fw_csr_rdat when ex.csr_access else ex.alu_rslt; 

    
    sp_ex_m1_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst or hz.m1_flush or not ex.valid) then
                m1.pc           <= (others=>'-');
                m1.valid        <= '0';
                m1.ctrl.reg_wr  <= '0';
                m1.ctrl.wrb_sel <= (others=>'-');
                m1.ctrl.mem_wr  <= '0';
                m1.ctrl.mem_rd  <= '0';
                m1.rs2_adr      <= (others=>'-');
                m1.rdst_adr     <= (others=>'-');
                m1.rs2_dat      <= (others=>'-');
                m1.funct3       <= (others=>'-');
                m1.exe_rslt     <= (others=>'-');
                m1.csr_access   <= '0';
                m1.csr_adr      <= (others=>'-');
                m1.csr_wdata    <= (others=>'-');
            elsif (hz.m1_enable) then
                m1.pc           <= ex.pc; 
                m1.valid        <= ex.valid;
                m1.ctrl.reg_wr  <= ex.ctrl.reg_wr;
                m1.ctrl.wrb_sel <= ex.ctrl.wrb_sel;
                m1.ctrl.mem_wr  <= ex.ctrl.mem_wr;
                m1.ctrl.mem_rd  <= ex.ctrl.mem_rd;
                m1.rs2_adr      <= ex.rs2_adr;
                m1.rdst_adr     <= ex.rdst_adr; 
                m1.rs2_dat      <= ex.ex_fw_rs2_dat;
                m1.funct3       <= ex.funct3; 
                m1.exe_rslt     <= ex.exe_rslt;
                m1.csr_access   <= ex.csr_access;
                m1.csr_adr      <= ex.csr_adr;
                m1.csr_wdata    <= ex.csr_wdata; 
            else 
                m1.ctrl.mem_wr  <= '0'; -- Don't want to send repeat requests to memory on a stall
                m1.ctrl.mem_rd  <= '0';
            end if; 
        end if;
    end process;


    -- =========================================================================
    -- Memory 1 Stage ==========================================================
    -- =========================================================================
    
    -- Forwarding Mux 
    ap_mem_fw_sel : process (all) 
    begin 
        if (wb.ctrl.reg_wr = '1' and wb.rdst_adr /= b"00000" and wb.rdst_adr = m1.rs2_adr) then
            m1.m1_fw_rs2_dat <= wb.rdst_dat;
        else 
            m1.m1_fw_rs2_dat <= m1.rs2_dat;
        end if; 
    end process; 


    -- Memory Request ----------------------------------------------------------
    -- -------------------------------------------------------------------------
    o_dren  <= m1.ctrl.mem_rd and hz.m2_enable;  
    o_dwen  <= m1.ctrl.mem_wr and hz.m2_enable;  
    o_daddr <= m1.exe_rslt; 
    o_dwdat <= m1.m1_fw_rs2_dat; 
    
    m1.trap.load_adr_ma  <= m1.ctrl.mem_rd and (o_daddr(1) or o_daddr(0));
    m1.trap.store_adr_ma <= m1.ctrl.mem_wr and (o_daddr(1) or o_daddr(0));

    ap_store_ben : process (all)
    begin
        case (m1.funct3) is
            when F3_SB  => o_dben <= b"0001";
            when F3_SH  => o_dben <= b"0011";   
            when F3_SW  => o_dben <= b"1111"; 
            when others => o_dben <= b"----";
        end case;
    end process;


    sp_m1_m2_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst or hz.m2_flush or not m1.valid) then
                m2.valid        <= '0'; 
                m2.pc           <= (others=>'-');
                m2.ctrl.reg_wr  <= '0'; 
                m2.ctrl.wrb_sel <= (others=>'-');
                m2.ctrl.mem_wr  <= '0';
                m2.ctrl.mem_rd  <= '0';
                m2.rdst_adr     <= (others=>'-');
                m2.exe_rslt     <= (others=>'-');
                m2.funct3       <= (others=>'-');
                m2.csr_access   <= '0';
                m2.csr_adr      <= (others=>'-');
                m2.csr_wdata    <= (others=>'-'); 
            elsif (hz.m2_enable) then
                m2.valid        <= m1.valid; 
                m2.pc           <= m1.pc;
                m2.ctrl.reg_wr  <= m1.ctrl.reg_wr;
                m2.ctrl.wrb_sel <= m1.ctrl.wrb_sel;
                m2.ctrl.mem_wr  <= m1.ctrl.mem_wr;
                m2.ctrl.mem_rd  <= m1.ctrl.mem_rd;
                m2.rdst_adr     <= m1.rdst_adr;
                m2.exe_rslt     <= m1.exe_rslt;
                m2.funct3       <= m1.funct3;
                m2.csr_access   <= m1.csr_access;
                m2.csr_adr      <= m1.csr_adr;
                m2.csr_wdata    <= m1.csr_wdata; 
            end if; 
        end if;
    end process;


    -- =========================================================================
    -- Memory 2 Stage ==========================================================
    -- =========================================================================
    -- Memory Response

    m2.trap.load_access  <= m2.ctrl.mem_rd and i_derror;
    m2.trap.store_access <= m2.ctrl.mem_wr and i_derror;
    m2.drdat <= i_drdat; -- memory read needs to be directly registered for timing

    sp_m2_wb_regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst or hz.wb_flush or not m2.valid) then
                wb.valid        <= '0'; 
                wb.pc4          <= (others=>'-');
                wb.ctrl.reg_wr  <= '0'; 
                wb.ctrl.wrb_sel <= (others=>'-');
                wb.rdst_adr     <= (others=>'-');
                wb.exe_rslt     <= (others=>'-');
                wb.funct3       <= (others=>'-');
                wb.csr_access   <= '0';
                wb.csr_adr      <= (others=>'-');
                wb.csr_wdata    <= (others=>'-'); 
                wb.drdat        <= (others=>'-'); 
            elsif (hz.wb_enable) then
                wb.valid        <= m2.valid; 
                wb.pc4          <= std_logic_vector(unsigned(m2.pc) + 4);
                wb.ctrl.reg_wr  <= m2.ctrl.reg_wr;
                wb.ctrl.wrb_sel <= m2.ctrl.wrb_sel;
                wb.rdst_adr     <= m2.rdst_adr;
                wb.exe_rslt     <= m2.exe_rslt;
                wb.funct3       <= m2.funct3;
                wb.csr_access   <= m2.csr_access;
                wb.csr_wdata    <= m2.csr_wdata;
                wb.csr_adr      <= m2.csr_adr;
                wb.drdat        <= m2.drdat;
            else
                wb.valid        <= '0'; -- dont want to double-count instructions that get stalled @ wb stage 
            end if; 
        
        end if;
    end process;


    -- =========================================================================
    -- Writeback Stage =========================================================
    -- =========================================================================

    ap_data_load : process (all)
    begin
        case (wb.funct3) is 
            when F3_LB  => 
                wb.memrd_dat(31 downto 8)  <= (others=>wb.drdat(7));
                wb.memrd_dat(7 downto 0)   <= wb.drdat(7 downto 0);

            when F3_LH  =>
                wb.memrd_dat(31 downto 16) <= (others=>wb.drdat(15));
                wb.memrd_dat(15 downto 0)  <= wb.drdat(15 downto 0);

            when F3_LW  => 
                wb.memrd_dat(31 downto 0)  <= wb.drdat;

            when F3_LBU =>
                wb.memrd_dat(31 downto 8)  <= (others=>'0');
                wb.memrd_dat(7 downto 0)   <= wb.drdat(7 downto 0);

            when F3_LHU => 
                wb.memrd_dat(31 downto 16) <= (others=>'0');
                wb.memrd_dat(15 downto 0)  <= wb.drdat(15 downto 0);

            when others => 
                wb.memrd_dat(31 downto 0)  <= (others=>'-');
        end case; 
    end process;

    ap_wrb_sel : process (all) 
    begin
        case (wb.ctrl.wrb_sel) is 
            when WRB_SEL_EXE => wb.rdst_dat <= wb.exe_rslt;
            when WRB_SEL_MEM => wb.rdst_dat <= wb.memrd_dat;
            when WRB_SEL_PC4 => wb.rdst_dat <= wb.pc4; 
            when others      => wb.rdst_dat <= (others=>'-');
        end case; 
    end process; 














    -- =========================================================================
    -- Hazard Unit =============================================================
    -- =========================================================================
    -- Detects and resolves pipeline hazards 


    -- TODO: This section is a giant glob of logic. See if I can do anything 
    -- to make it smaller.

    -- Decode stage data hazards  ---------------------------------------
    -- -------------------------------------------------------------------------
    -- These are only a problem because we calculate branches in the decode stage
    -- If I move branches up to execute for possible timing improvements then 
    -- I can also remove this hazard section.

    hz.id_ex_br_hazard <= '1' when id.ctrl.branch = '1' 
                      and ex.ctrl.reg_wr = '1' 
                      and ex.rdst_adr /= b"00000" 
                      and (ex.rdst_adr = id.rs1_adr 
                       or ex.rdst_adr = id.rs2_adr) 
                    else '0';

    hz.id_ex_jalr_hazard <= '1' when id.ctrl.jalr = '1' 
                        and ex.ctrl.reg_wr = '1' 
                        and ex.rdst_adr /= b"00000" 
                        and (ex.rdst_adr = id.rs1_adr) 
                    else '0';  

    hz.id_m1_br_hazard <= '1' when id.ctrl.branch = '1' 
                             and m1.ctrl.mem_rd = '1' 
                             and m1.rdst_adr /= b"00000" 
                             and (m1.rdst_adr = id.rs1_adr 
                              or m1.rdst_adr = id.rs2_adr) 
                    else '0'; 

    hz.id_m1_jalr_hazard <= '1' when id.ctrl.jalr = '1' 
                               and m1.ctrl.mem_rd = '1' 
                               and m1.rdst_adr /= b"00000" 
                               and m1.rdst_adr = id.rs1_adr 
                    else '0'; 

    hz.id_m2_br_hazard <= '1' when id.ctrl.branch = '1' 
                        and m2.ctrl.mem_rd = '1' 
                        and m2.rdst_adr /= b"00000" 
                        and (m2.rdst_adr = id.rs1_adr 
                         or m2.rdst_adr = id.rs2_adr) 
               else '0'; 

    hz.id_m2_jalr_hazard <= '1' when id.ctrl.jalr = '1' 
                          and m2.ctrl.mem_rd = '1' 
                          and m2.rdst_adr /= b"00000" 
                          and m2.rdst_adr = id.rs1_adr 
               else '0'; 


    -- Execute stage data hazards  ---------------------------------------
    -- -------------------------------------------------------------------------
    -- Stall on rs1 for csr and alu operations
    hz.ex_m1_csr_hazard <= '1' when  
            ex.ctrl.reg_wr = '1'
            and  m1.ctrl.mem_rd = '1' 
            and  m1.rdst_adr /= b"00000"
            and (m1.rdst_adr = ex.rs1_adr) 
        else '0'; 

    -- CSR operations only read rs1, so only stall rs2 if this is an alu operation
    -- and NOT a CSR operation. TODO: TODO: can add a signal stating if this is a r-type csr or an immediate csr. 
    -- I dont have to stall if its an immediate CSR, so that is another thing we can check for to prevent 
    -- an unnecessary stall. 
    hz.ex_m1_alu_hazard <= '1' when  ex.ctrl.reg_wr = '1' and not ex.csr_access = '1'
                        and  m1.ctrl.mem_rd = '1' 
                        and  m1.rdst_adr /= b"00000"
                        and (m1.rdst_adr = ex.rs2_adr) 
                        else '0'; 

    hz.ex_m2_csr_hazard <= '1' when  ex.ctrl.reg_wr = '1'
                            and  m2.ctrl.mem_rd = '1' 
                            and  m2.rdst_adr /= b"00000"
                            and (m2.rdst_adr = ex.rs1_adr) 
                            else '0'; 
      
    hz.ex_m2_alu_hazard <= '1' when  ex.ctrl.reg_wr = '1' and not ex.csr_access = '1'
                              and  m2.ctrl.mem_rd = '1' 
                              and  m2.rdst_adr /= b"00000"
                              and (m2.rdst_adr = ex.rs2_adr) 
                              else '0'; 


    -- Stall if store is in execute and load is in m1
    hz.ex_m1_ls_hazard <= '1' when ex.ctrl.mem_wr = '1' 
                            and  m1.ctrl.mem_rd = '1' 
                            and  m1.rdst_adr /= b"00000"
                            and (m1.rdst_adr = ex.rs2_adr) 
                            else '0'; 

    -- Memory transaction hazards
    -- These stall the pipe if a memory access takes > one clockcycle.
    -- All BRAM and/or cache hits should not stall.
    hz.imem_hazard <= '1' when f2.iren and not i_iack else '0'; 
    hz.dmem_hazard <= '1' when (m2.ctrl.mem_wr or m2.ctrl.mem_rd) and not i_dack else '0';



    -- Stalling & Flushing -----------------------------------------------------
    -- -------------------------------------------------------------------------   
    ap_pipeline_ctrl : process (all)
    begin
        -- Defaults 
        hz.f1_enable <= '1'; 
        hz.f2_enable <= '1'; 
        hz.id_enable <= '1';
        hz.ex_enable <= '1';
        hz.m1_enable <= '1';
        hz.m2_enable <= '1';
        hz.wb_enable <= '1';
        hz.f1_flush  <= '0'; 
        hz.f2_flush  <= '0'; 
        hz.id_flush  <= '0';
        hz.ex_flush  <= '0';
        hz.m1_flush  <= '0';
        hz.m2_flush  <= '0';
        hz.wb_flush  <= '0';



        -- Turn a wfi instruction into a nop 
        -- TODO: Implementing wfi is low priority. Dont worry about this till
        -- everything else works. 
        if (ex.wfi) then 
            hz.m1_flush <= '1'; 
        end if; 
        


        -- Control Hazard Flushes ----------------------------------------------
        -- Memory 2 stage exceptions 
        if (m2.trap.load_access or m2.trap.store_access) then
            hz.f2_flush  <= '1'; 
            hz.id_flush  <= '1';
            hz.ex_flush  <= '1';
            hz.m1_flush  <= '1';
            hz.m2_flush  <= '1';
            hz.wb_flush  <= '1';
        end if;

        -- Memory 1 stage exceptions 
        if (m1.trap.load_adr_ma or m1.trap.store_adr_ma) then
            hz.f2_flush  <= '1'; 
            hz.id_flush  <= '1';
            hz.ex_flush  <= '1';
            hz.m1_flush  <= '1';
            hz.m2_flush  <= '1';
        end if;

        -- Execute stage exceptions & mret
        -- TODO: Doublecheck the RISC-V Spec about weather or not mret, ecall, 
        -- and ebreak should add to the instret counter. I may need a new section
        -- that doesnt kill that instruction
        if (ex.trap.illeg_instr or ex.trap.ecall or ex.trap.ebreak or 
                ex.trap.instr_adr_ma or ex.trap.instr_access or ex.mret) then
            hz.f2_flush  <= '1'; 
            hz.id_flush  <= '1';
            hz.ex_flush  <= '1';
            hz.m1_flush  <= '1';
        end if; 

        -- Decode stage branches
        if (id.br_taken) then
            hz.f2_flush  <= '1'; 
            hz.id_flush  <= '1';
        end if;



        -- Wait on Memory Accesses ---------------------------------------------
        if (hz.dmem_hazard) then -- pause the pipe while waiting on dmem
            hz.f1_enable <= '0'; 
            hz.f2_enable <= '0'; 
            hz.id_enable <= '0';
            hz.ex_enable <= '0';
            hz.m1_enable <= '0';
            hz.m2_enable <= '0';
            hz.wb_flush  <= '1';

        elsif (hz.imem_hazard) then -- pause the pipeline while waiting on the imem
            hz.f1_enable <= '0'; 
            hz.f2_enable <= '0'; 
            hz.id_flush  <= '1';
        end if;


        -- Data Hazards --------------------------------------------------------
        -- Decode Stage Stalls
        if (hz.id_ex_br_hazard or hz.id_ex_jalr_hazard or hz.id_m1_br_hazard or
                hz.id_m1_jalr_hazard or hz.id_m2_br_hazard or hz.id_m2_jalr_hazard) then 
            hz.f1_enable <= '0'; 
            hz.f2_enable <= '0'; 
            hz.id_enable <= '0';
            hz.ex_flush  <= '1'; 
        end if; 
        
        -- Execute Stage Stalls
        if (hz.ex_m1_csr_hazard or hz.ex_m1_alu_hazard or hz.ex_m2_csr_hazard or 
                hz.ex_m2_alu_hazard or hz.ex_m1_ls_hazard) then 
            hz.f1_enable <= '0'; 
            hz.f2_enable <= '0'; 
            hz.id_enable <= '0';
            hz.ex_enable <= '0';
            hz.m1_flush  <= '1'; 
        end if; 
        
    end process;






    -- =========================================================================
    -- Performance Counters ====================================================
    -- =========================================================================
    -- Cycle Counter 
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            ct.mcycle <= std_logic_vector(unsigned(ex.csr.mcycle) + 1);
        end if;
    end process;
    

    -- Instructions Retired Counter 
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (wb.valid) then
                ct.minstret <= std_logic_vector(unsigned(ex.csr.minstret) + 1);
            end if; 
        end if;
    end process;

end architecture;


