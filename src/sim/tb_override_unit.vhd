library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.sys_config_pkg.all;
use work.can_test_vec_pkg.all;
use ieee.numeric_std.all;


entity tb_override_unit is
end;

architecture bench of tb_override_unit is
    
    signal cfg_en_i : std_logic;
    signal fi_frame_i : fi_frame_t;
    signal fi_frame_ready_i : std_logic;
    signal data_vector_ready_i : std_logic;
    signal data_override_i : std_logic_vector(0 to 575);
    signal fsm_state_io : fsm_state_types;
    signal fsm_cnt_io : integer range 0 to 512;
    signal dlc_buffer_io : std_logic_vector(3 downto 0);
    signal dlc_ready_io : std_logic;
    signal bs_insert_io : std_logic;
    signal bs_insert_dynamic_io : std_logic;
    signal bs_state_io : bs_state_types := MONITOR;
    signal bs_crc_cnt_io : integer;
    signal bs_crc_mode_io : std_logic;
    signal fd_mode_io : std_logic;
    signal sample_buff_io : std_logic;
    signal sample_buff_ready_io : std_logic;
    signal eof_stat_io : std_logic;
    signal pre_sample_point_i : std_logic;
    signal pre_sample_point_strobe_i : std_logic;
    signal injection_arm_o : std_logic;
    signal xcvr_mode_req_o : std_logic;
    signal xcvr_strb_i : std_logic := '0';
    signal inj_err_miss_o : std_logic;
    signal inj_err_dom_o : std_logic;
    signal inj_err_dlc_o : std_logic;
    signal inj_err_fsm_o : std_logic;
    signal inj_pending_o : std_logic;
    signal interrupt_req_o : std_logic;
    
    signal tb_fi_err : std_logic_vector(2 downto 0);

    signal tb_data_crc_ov_buffer : std_logic_vector(0 to DATA_CRC_WIDTH - 1) := (others => '0');
    signal tb_dlc_ov_buffer : std_logic_vector(3 downto 0) := (others => '0');


    signal tb_ctrl_buffer : STD_LOGIC_VECTOR (3 downto 0);
    signal tb_data_buffer : STD_LOGIC_VECTOR (511 downto 0);
    signal tb_crc_stf_buffer : STD_LOGIC_VECTOR (3 downto 0);
    signal tb_crc_buffer : STD_LOGIC_VECTOR (20 downto 0);
    signal tb_id_buffer : STD_LOGIC_VECTOR (28 downto 0);
    signal tb_dlc_buffer : STD_LOGIC_VECTOR (3 downto 0);

    signal clk: STD_LOGIC := '0';
    signal reset_n: STD_LOGIC := '1';
    signal sample_i: STD_LOGIC := '0';
    signal sample_strb_i: STD_LOGIC := '0';
    signal brs_pend_stat_o : STD_LOGIC := '0';
    signal crc_del_pend_stat_o : STD_LOGIC := '0';
    signal err_stat_o : STD_LOGIC := '0';
    signal hard_sync_req_o : STD_LOGIC := '0';
    signal sleep_i : STD_LOGIC := '0';
    signal fip_strb_i : std_logic := '0';

    signal data_width_io : INTEGER range 0 to 512;
    signal crc_width_io : INTEGER range 0 to 21;

    -- Information about the current Destuffer state
    signal bs_shift_io : std_logic_vector (4 downto 0) := "01010"; 

    
    signal curr_data_vector_idx : integer := 0;
    signal curr_fi_vector_idx : integer := 0;
    signal curr_bit_idx : integer := 0;

    constant clk_period : time := 10 ns;


    function fi_field_map (encoded_field_val : in std_logic_vector(2 downto 0)) return fsm_state_types is
        variable decoded_state : fsm_state_types;
    begin
        case encoded_field_val is
            when "000" => decoded_state := ABIT;
            when "001" => decoded_state := CTRL;
            when "011" => decoded_state := DATA;
            when "100" => decoded_state := CRC_STF;
            when "101" => decoded_state := CRC;
            when "110" => decoded_state := EOF;
            when others => decoded_state := ERRF;        
        end case;

        return decoded_state;
    end function;

begin
    uut: entity work.can_fsm PORT MAP (
        clk                  => clk,
        reset_n              => reset_n,
        sample_i            => sample_i,
        sample_strb_i      => sample_strb_i,
        eof_stat_o         => eof_stat_io,
        brs_pend_stat_o => brs_pend_stat_o,
        crc_del_pend_stat_o => crc_del_pend_stat_o,
        err_stat_o => err_stat_o, 
        hard_sync_req_o   => hard_sync_req_o,
        sleep_i             => sleep_i,

        -- Debug Mapping
        tb_ctrl_buffer_o    => tb_ctrl_buffer,
        tb_data_buffer_o    => tb_data_buffer,
        tb_crc_stf_buffer_o => tb_crc_stf_buffer,
        tb_crc_buffer_o     => tb_crc_buffer,
        tb_id_buffer_o      => tb_id_buffer,
        tb_dlc_buffer_o     => tb_dlc_buffer,


        fsm_state_o  => fsm_state_io,
        fsm_cnt_o    => fsm_cnt_io,
        dlc_buffer_o => dlc_buffer_io,
        dlc_ready_o  => dlc_ready_io,
        bs_insert_o  => bs_insert_io,
        bs_insert_dynamic_o => bs_insert_dynamic_io,
        bs_shift_o => bs_shift_io,
        bs_state_o => bs_state_io,
        bs_crc_cnt_o => bs_crc_cnt_io,
        bs_crc_mode_o => bs_crc_mode_io,
        fd_mode_o    => fd_mode_io,
        data_width_o => data_width_io,
        crc_width_o => crc_width_io,

        sample_buff_o => sample_buff_io,
        sample_buff_ready_o => sample_buff_ready_io


    );

    override_unit_inst : entity work.override_unit
    port map (
        clk                       => clk,
        reset_n                   => reset_n,
        sleep_i                   => sleep_i,
        fi_frame_i                => fi_frame_i,
        fi_frame_ready_i          => fi_frame_ready_i,
        data_vector_ready_i       => data_vector_ready_i,
        data_override_i           => data_override_i,
        fsm_state_i               => fsm_state_io,
        fsm_cnt_i                 => fsm_cnt_io,
        dlc_buffer_i              => dlc_buffer_io,
        dlc_ready_i               => dlc_ready_io,
        bs_insert_i               => bs_insert_io,
        bs_state_i                => bs_state_io,
        bs_shift_i                => bs_shift_io,
        bs_crc_cnt_i              => bs_crc_cnt_io,
        bs_crc_mode_i             => bs_crc_mode_io,
        bs_insert_dynamic_i       => bs_insert_dynamic_io,
        fd_mode_i                 => fd_mode_io,
        sample_buff_i             => sample_buff_io,
        sample_buff_ready_i       => sample_buff_ready_io,
        pre_sample_point_i        => pre_sample_point_i,
        pre_sample_point_strobe_i => pre_sample_point_strobe_i,
        fip_strb_i                => fip_strb_i,
        data_width_i              => data_width_io,
        crc_width_i               => crc_width_io,
        injection_arm_o           => injection_arm_o,
        xcvr_mode_req_o           => xcvr_mode_req_o,
        xcvr_strb_i               => xcvr_strb_i,
        inj_err_miss_o            => inj_err_miss_o,
        inj_err_dom_o             => inj_err_dom_o,
        inj_err_dlc_o             => inj_err_dlc_o,
        inj_err_fsm_o             => inj_err_fsm_o,
        inj_pending_o             => inj_pending_o,
        interrupt_req_o           => interrupt_req_o
    );

    


    clk_process : process
    begin 
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Assembly of internal error flags to a larger vector for comparison
    tb_fi_err <= inj_err_miss_o & inj_err_dom_o & inj_err_dlc_o;     

    sim_sample_wire : process

        -- Declared here rather than in the architecture: GHDL cannot resolve
        -- external names against a directly instantiated entity at that point.
        alias tb_override_triggered is << signal .tb_override_unit.override_unit_inst.tb_override_triggered : std_logic >>;
        alias tb_override_queued is << signal .tb_override_unit.override_unit_inst.tb_override_queued : std_logic >>;
        alias tb_bs_cnt is << signal .tb_override_unit.override_unit_inst.bs_cnt_r : integer >>;
        alias shadow_fsm_state_r is << signal .tb_override_unit.override_unit_inst.shadow_fsm_state_r :fsm_state_types >>;

        variable curr_fi_test_frame : fi_tb_frame_t;
        variable curr_fi_frame : fi_frame_t;
        variable tb_inj_ov_sample : std_logic;
        variable curr_data_idx : integer;
        variable curr_dlc_idx : integer;
        variable override_started : std_logic;
        variable bit_idx : integer;

        variable expected_error : std_logic;

        variable shadow_reg_snapshot : fsm_state_types := ABIT;
        variable bs_insert_idx_snapshot : integer;
        variable bs_insert_state_snapshot : fsm_state_types;
        variable bs_insert_prev : std_logic;
        variable bs_insert_snapshot_prev : std_logic; 

        variable main_actor_activated : std_logic;
    begin

        -- Recessive Bus
        reset_n <= '0';
        sample_i <= '1';
        sample_strb_i <= '0';

        -- Wait for 3 Cycles (Not really necessary, but for better overview)
        
        for k in 1 to 3 loop
            wait until rising_edge(clk);
        end loop;

        reset_n <= '1';
        -- FI Test vector iteration
        for i in FI_TEST_FRAMES'range loop
            report "Evaluating Vector #" & integer'image(i);
            
            curr_fi_test_frame := FI_TEST_FRAMES(i);
            curr_fi_vector_idx <= i;
            curr_data_vector_idx <= curr_fi_test_frame.fi_target_frame_idx;
            wait for 0 ns;
            sleep_i <= '1';
            sample_i <= '1'; 
            sample_strb_i <= '0';

            curr_data_idx := 0;
            curr_dlc_idx := 3;

            tb_data_crc_ov_buffer <= (others => '0');
            tb_dlc_ov_buffer <= D_TEST_FRAMES(curr_data_vector_idx).dlc;
            override_started := '0';

            bs_insert_idx_snapshot := 0;
            bs_insert_state_snapshot := ABIT;
            bs_insert_snapshot_prev := '0';

            main_actor_activated := '0';

            ----
            -- IFS after every frame of at least 7 Bit (Or cycles for testing purposes)
            ----

            -- Feed the relevant FI-frames to the unit
            curr_fi_frame := (
                fi_type => curr_fi_test_frame.fi_type,
                fi_field => curr_fi_test_frame.fi_field,
                fi_meta => curr_fi_test_frame.fi_meta
            );
            

            fi_frame_i <= curr_fi_frame;
            fi_frame_ready_i <= '0';
            data_override_i <= curr_fi_test_frame.fi_data_vec;
            data_vector_ready_i <= '0';

            for k in 1 to 7 loop
                wait until rising_edge(clk);
            end loop;


            sleep_i <= '0';

            wait until rising_edge(clk);

            bit_idx := 0;
            -- Iterate over data vector bits / override vector bits, until the FSM triggers an EOF
            while sleep_i = '0' loop
                curr_bit_idx <= bit_idx;


                -- Stage II of OU has updated its state, injection queue ready 
                wait until rising_edge(clk);


                -- PSP - 1 
                wait until rising_edge(clk);
                -- Emulate a pre-sample-point provided by the TU
                -- Emulate a Error-Passive sender by stop transmitting after the first override
                if bit_idx > 0 then
                    pre_sample_point_i <= D_TEST_FRAMES(curr_data_vector_idx).raw_frame(bit_idx) when override_started = '0' else '1';
                    pre_sample_point_strobe_i <= '1'; 
                end if;

                
                -----------
                -- Pre sample point
                -----------

                -- PSP 
                -- PSP is registered
                wait until rising_edge(clk);

                pre_sample_point_strobe_i <= '0'; 


                -- IP - 1
                -- Injection arm is ready
                wait until rising_edge(clk);


                -- Assemble the Data and DLC vectors from the OU Injection point output
                -- Note: this should only be done for the injection mode, not the actor mode. For Actor mode we use a lookahead
                if (curr_fi_test_frame.fi_err = "000" or curr_fi_test_frame.fi_err = "010") and tb_fi_err = "000" and fsm_state_io /= ERRF then
                    if curr_fi_test_frame.fi_type = FI_DATA then
                        if bs_insert_io = '0' and (fsm_state_io = DATA or fsm_state_io = CRC_STF or fsm_state_io = CRC) then 
                            assert curr_data_idx < DATA_CRC_WIDTH report "Override vector has invalid length" severity failure;
                            tb_data_crc_ov_buffer(curr_data_idx) <= not injection_arm_o;
                            curr_data_idx := curr_data_idx + 1;
                        end if;
                    elsif curr_fi_test_frame.fi_type = FI_DLC then
                        if bs_insert_io = '0' and fsm_state_io = CTRL and fsm_cnt_io > 3 then
                            tb_dlc_ov_buffer(curr_dlc_idx) <= (not injection_arm_o);
                            curr_dlc_idx := curr_dlc_idx - 1;
                        end if;
                    end if;
                end if;


                if tb_override_triggered then
                    -- Tells the raw vector (Sender) to stop pushing values
                    override_started := '1' when injection_arm_o = '1' else override_started;

                    ----
                    -- Check for injection offset to GT data correspondence
                    ----

                    if curr_fi_test_frame.fi_type = FI_BIT then
                        assert fsm_cnt_io = to_integer(unsigned(curr_fi_test_frame.fi_meta)) report "Invalid Inj pos"  severity failure;                
                        assert fsm_state_io = fi_field_map(curr_fi_test_frame.fi_field) report "Invalid Inj field"  severity failure;                
                    elsif curr_fi_test_frame.fi_type = FI_BSDY and bs_insert_io = '1' and injection_arm_o = '1' then 
                        assert shadow_reg_snapshot = fi_field_map(curr_fi_test_frame.fi_field) severity failure;                
                        assert tb_bs_cnt = to_integer(unsigned(curr_fi_test_frame.fi_meta)) report "Invalid Count" severity failure;
                    elsif curr_fi_test_frame.fi_type = FI_BSFX and bs_insert_io = '1' and injection_arm_o = '1' then 
                        assert fsm_state_io = CRC_STF or fsm_state_io = CRC report "Invalid Inj field"  severity failure;                
                        assert tb_bs_cnt = to_integer(unsigned(curr_fi_test_frame.fi_meta)) report "Invalid Count" severity failure;
                    end if;

                end if;

                ----
                -- Check for Value correspondence
                ----

                -- Note: Needs adjustment for the main actor mode
                if curr_fi_test_frame.fi_err = "000" and pre_sample_point_i = '1' and tb_override_queued = '0' then
                    assert injection_arm_o = '1' report "Override does not match the error" severity failure;
                -- If override dominaint error then the first data override should be at a dominaint bit and afterwards we should encounter no more writes
                elsif curr_fi_test_frame.fi_err = "010" and pre_sample_point_i = '0' and tb_override_queued = '0' then
                    assert injection_arm_o = '0' report "Override does not match the error" severity failure;
                --- For "Bit not found" we should never encounter an override
                elsif curr_fi_test_frame.fi_err = "100" then
                    assert injection_arm_o = '0' report "Override does not match the error" severity failure;
                end if;

                ----
                -- Injection Point
                ----

                -- IP 
                -- The TU has acted on the injection_arm signal and placed the value on the TX line
                fip_strb_i <= '1';
                wait until rising_edge(clk);
                fip_strb_i <= '0';

                -- Emulate the bus / TU response
                if injection_arm_o = '1' then
                    tb_inj_ov_sample := '0';
                else
                    -- Emulate a Error-Passive sender by stop transmitting after the first override
                    tb_inj_ov_sample := D_TEST_FRAMES(curr_data_vector_idx).raw_frame(bit_idx) when override_started = '0' else '1';
                end if;

                ----
                -- Sample Point
                ----

                -- SP 
                -- The TU triggers a SP signal
                -- Pass injected data to the FSM

                sample_i <= tb_inj_ov_sample;
                sample_strb_i <= '1';

                -- SP + 1 
                -- The FSM has updated its state and provides a Sample_buff strobe
                wait until rising_edge(clk);

                -- We should never encounter an error if we perform data override, as those should follow the protocol as long as the vector is valid
                -- For DLC, the error should only in the data and not in the DLC section
                if curr_fi_test_frame.fi_err = "000" then
                    if curr_fi_test_frame.fi_type = FI_DATA then
                        assert fsm_state_io /= ERRF and inj_err_fsm_o = '0' report "Encountered Error at data frame" severity failure;
                    elsif curr_fi_test_frame.fi_type = FI_DLC and fsm_state_io = CTRL then
                        assert fsm_state_io /= ERRF and inj_err_fsm_o = '0' report "Encountered Error at DLC frame" severity failure;
                    end if;
                end if;


                ----
                -- Intermission Period bw SP and PSP, being min of 3 TQ / 3 Cycles (Phase_Seg_2 + Sync_Seg = 2 + 1)
                ----

                sample_strb_i <= '0';
                shadow_reg_snapshot := shadow_fsm_state_r; 

                if xcvr_mode_req_o = '1' then
                    xcvr_strb_i <= '1';
                end if;
                -- SP + 2 
                -- Destuffer has updated it's state
                -- Stage I OU has updated it's state
                wait until rising_edge(clk);
                xcvr_strb_i <= '0';

                -- Simulate Memory Unit parsing the FI frames
                -- Note, this usually takes more than 1 cycle
                if fsm_state_io > ABIT then
                    fi_frame_ready_i <= '1';
                    data_vector_ready_i <= '1';
                end if;

                -- Enable sleep early when the FSM is offline (Emulates the TU behavior)
                if eof_stat_io = '1' then
                    sleep_i <= '1';
                    wait until rising_edge(clk);
                    wait until rising_edge(clk);
                    assert interrupt_req_o = '1'  report "Interrupt not raised" severity failure;
                end if;

                -- Wait for the intermission period
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                
                -- Update the stuffing bookkeeping for Edge case FI_BIT error prediction
                if bs_insert_prev = '0' and bs_insert_io = '1' then
                    bs_insert_idx_snapshot := fsm_cnt_io;
                    bs_insert_state_snapshot := fsm_state_io;
                    bs_insert_snapshot_prev := tb_inj_ov_sample;
                end if;
                bs_insert_prev := bs_insert_io;


                bit_idx := bit_idx + 1;
                if bit_idx > D_TEST_FRAMES(curr_data_vector_idx).raw_frame_len - 1 then
                    assert override_started = '1' report "Reached max. width of vector without override" severity failure; 
                end if;
                assert bit_idx < 744 report "FSM did not terminate after max. possible bit length" severity failure;
                    

            end loop;

            wait until rising_edge(clk);

            ----
            -- Final Error state checking
            ----

            -- Basically, this part checks for injections close to the EOF, if a BSErr can still occur after the injection or if the Parser is either already far enough in the frame\ 
            -- that the destuffer is deactivated, or if there were no more stuffing bits after the insertion. Based on either it predicts the error state the FSM should take 
            if curr_fi_test_frame.fi_type = FI_BIT then
                -- If we are not in the edge case, we just expect an error as usual
                expected_error := '1';

                if fi_field_map(curr_fi_test_frame.fi_field) = CRC then
                    -- Check if the Frame is an FD frame
                    if D_TEST_FRAMES(curr_data_vector_idx).ctrl(3) = '1' then
                        if D_TEST_FRAMES(curr_data_vector_idx).data_len > 128 then
                            -- For CRC 21 its limited to values after the last stuffing, which is located after the pre to last crc
                            -- Except for the bit before the stuff, where the recessive 1 on the bus is registered as a stuff
                            expected_error := '0' when to_integer(unsigned(curr_fi_frame.fi_meta)) > 18 else '1';
                        else 
                            expected_error := '0' when to_integer(unsigned(curr_fi_frame.fi_meta)) > 14 else '1';
                        end if;
                    else
                        -- For dynamic stuffing this gets much more complicated, we need to compare against the dynamic stuffing bit position in the crc vector
                        -- Check if BS Check happens somewhere after the injection
                        if ((bs_insert_state_snapshot = CRC and bs_insert_idx_snapshot > to_integer(unsigned(curr_fi_frame.fi_meta))) or bs_insert_state_snapshot = EOF) 
                            and bs_insert_snapshot_prev = '1' then
                            -- Check if it is recessive 
                            if bs_insert_snapshot_prev = '1' then
                                expected_error := '1';
                            else 
                                expected_error := '0';
                            end if;
                        else
                            expected_error := '0';
                        end if;
                    end if;
            
                elsif fi_field_map(curr_fi_test_frame.fi_field) = EOF then
                    expected_error := '0' when to_integer(unsigned(curr_fi_frame.fi_meta)) < 2 else '1';
                end if;
            end if;

            -- Check for the internal Error flags: Bit not encountered, etc..
            assert tb_fi_err = curr_fi_test_frame.fi_err 
            report "Internal Error doesn't match! Expected: " & to_string(curr_fi_test_frame.fi_err) & ", Got: " & to_string(tb_fi_err) severity failure;          
           
            -- Check for expected FSM state
            if curr_fi_test_frame.fi_err = "000" then
                if curr_fi_test_frame.fi_type = FI_DATA then
                    assert inj_err_fsm_o = '0' report "FSM in error state after Data injection" severity failure;
                elsif curr_fi_test_frame.fi_type = FI_BIT then
                    assert inj_err_fsm_o = expected_error report "Bit injection error state does not match!" & 
                    "Expected " & std_logic'image(expected_error) & ", Got: " & std_logic'image(inj_err_fsm_o) severity failure;
                elsif curr_fi_test_frame.fi_type = FI_BSDY or curr_fi_test_frame.fi_type = FI_BSFX then
                    assert inj_err_fsm_o = '1' report "FSM not in error state after BS injection" severity failure;
                elsif curr_fi_test_frame.fi_type = FI_DLC and curr_fi_frame.fi_meta /= "000001111" then
                    assert inj_err_fsm_o = '1' report "FSM not in error state after DLC injection" severity failure;
                end if;
            elsif curr_fi_test_frame.fi_err = "100" then
                if curr_fi_test_frame.fi_type = FI_DATA then
                    report "This case should not happen, check generator" severity failure;
                elsif curr_fi_test_frame.fi_type = FI_BIT then
                    assert inj_err_fsm_o = '0' report "FSM in error state after failed Bit injection" severity failure;
                elsif curr_fi_test_frame.fi_type = FI_BSDY or curr_fi_test_frame.fi_type = FI_BSFX then
                    assert inj_err_fsm_o = '0' report "FSM in error state after failed BS injection" severity failure;
                elsif curr_fi_test_frame.fi_type = FI_DLC then
                    report "This case should not happen, check generator" severity failure;
                end if;
            elsif curr_fi_test_frame.fi_err = "010" then
                if curr_fi_test_frame.fi_type = FI_DATA then
                    assert inj_err_fsm_o = '0' report "FSM in error state after failed Data injection" severity failure;
                elsif curr_fi_test_frame.fi_type = FI_BIT then
                    assert inj_err_fsm_o = '0' report "FSM in error state after failed Bit injection" severity failure;
                elsif curr_fi_test_frame.fi_type = FI_BSDY or curr_fi_test_frame.fi_type = FI_BSFX then
                    assert inj_err_fsm_o = '0' report "FSM in error state after failed BS injection" severity failure;
                elsif curr_fi_test_frame.fi_type = FI_DLC then
                    assert inj_err_fsm_o = '0' report "FSM in error state after failed Data injection" severity failure;
                end if;
            elsif curr_fi_test_frame.fi_err = "001" then
                if curr_fi_test_frame.fi_type = FI_DATA then
                    assert inj_err_fsm_o = '0' report "FSM in error state after failed Data injection" severity failure;
                elsif curr_fi_test_frame.fi_type = FI_BIT then
                    report "This case should not happen, check generator" severity failure;
                elsif curr_fi_test_frame.fi_type = FI_BSDY or curr_fi_test_frame.fi_type = FI_BSFX then
                    report "This case should not happen, check generator" severity failure;
                elsif curr_fi_test_frame.fi_type = FI_DLC then
                    report "This case should not happen, check generator" severity failure;
                end if;
            end if;

            ----
            -- Check Data buffer content
            ----

            -- Check if the data crc part contians the correct values for FI_DATA
            if curr_fi_test_frame.fi_type = FI_DATA then
                assert tb_data_crc_ov_buffer = curr_fi_test_frame.fi_gt_data_out report "Data override vector doesn't match" severity failure;
            elsif curr_fi_test_frame.fi_type = FI_DLC then
                assert tb_dlc_ov_buffer = curr_fi_test_frame.fi_meta(3 downto 0) report "DLC Override output doesn't match" severity failure;
            end if;



            sleep_i <= '1'; 
            sample_i <= '1'; 
            sample_strb_i <= '0';

            wait until rising_edge(clk);
            
            -- Wait for OU update
            wait until rising_edge(clk);
            
        end loop;

        assert false report "Test Successful!" severity failure;
    end process;

end;
