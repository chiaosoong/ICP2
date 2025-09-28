//------------------------------------------------------------------------------
// SERIAL_DATA uVC sequence driver 
//
// The driver generates serial data according to the configuration of the
// serial_data_config object and activates the start bit when specified.
// The driver can generate parity bits if parity_enable is set.
// 
//  The configuration of the serial interface is provided via the
//  serial_data_config object.
//
//------------------------------------------------------------------------------
class serial_data_driver extends uvm_driver #(serial_data_seq_item);
    `uvm_component_param_utils(serial_data_driver)

    // SERIAL_DATA uVC configuration object.
    serial_data_config  m_config;
    
    bit parity_bit;
    //------------------------------------------------------------------------------
    // The constructor for the component.
    //------------------------------------------------------------------------------
    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        if (!uvm_config_db #(serial_data_config)::get(this,"","serial_data_config", m_config)) begin
            `uvm_fatal(get_name(),"Cannot find the VC configuration!")
        end
    endfunction

    //------------------------------------------------------------------------------
    // FUNCTION: build
    // The build phase for the component.
    //------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction : build_phase

    //------------------------------------------------------------------------------
    // FUNCTION: run_phase
    // The run phase for the component.
    // - Main loop
    // -  Wait for sequence item.
    // -  Perform the requested action
    // -  Send a response back.
    //------------------------------------------------------------------------------
    virtual task run_phase(uvm_phase phase);
        serial_data_seq_item seq_item;

        // Reset signals
        m_config.m_vif.start_bit <= 0;
        m_config.m_vif.serial_data <= 0;

        //---------- Task 2.1/2.2 ---------//
        m_config.m_vif.parity_enable <= m_config.parity_enable;
        
        forever begin
            // Wait for sequence item
            seq_item_port.get(seq_item);
            `uvm_info(get_name(),$sformatf("Start serial interface transaction. Delay start bit=%0d  Start bit length=%0d  Serial data=%08b", seq_item.start_bit_delay, seq_item.start_bit_length, seq_item.serial_data),UVM_LOW)             
            
            // Perform the requested action and send response back.
            //---------- Task 1.1 ---------//
            /*
            for (int i=0; i<8; i++) begin
                @(posedge m_config.m_vif.clk);
                m_config.m_vif.serial_data <= seq_item.serial_data[i];
                if (i==0) m_config.m_vif.start_bit <= 1;
                else      m_config.m_vif.start_bit <= 0;
            end
            */

            //---------- Task 1.2 ---------//
            fork
                // control start_bit delay and length
                begin
                    repeat(seq_item.start_bit_delay)
                        @(posedge m_config.m_vif.clk);

                    m_config.m_vif.start_bit <= 1;
                    repeat(seq_item.start_bit_length)
                        @(posedge m_config.m_vif.clk);
                    m_config.m_vif.start_bit <= 0;
                end

                begin
                    for (int i = 0; i < 8; i++) begin
                        @(posedge m_config.m_vif.clk);
                        m_config.m_vif.serial_data <= seq_item.serial_data[i];
                    end
                end
            join

            //---------- Task 2.3/2.4 ---------//
            if (m_config.parity_enable) begin
                `uvm_info(get_name(),$sformatf("PARITY ENABLE!!!"),UVM_LOW);
                parity_bit = ($countones(seq_item.serial_data) % 2 == 1) ? 0 : 1; 
                if (seq_item.parity_error) begin
                    parity_bit = ~parity_bit;
                    `uvm_info(get_name(),$sformatf("Generate error parity bit!!! Parity bit = %0d", parity_bit), UVM_LOW);
                end
                else
                    `uvm_info(get_name(),$sformatf("Generate correct parity bit!!! Parity bit = %0d", parity_bit), UVM_LOW);
                @(posedge m_config.m_vif.clk);
                m_config.m_vif.serial_data <= parity_bit;
            end
            @(posedge m_config.m_vif.clk);
            m_config.m_vif.serial_data <= 0;

            seq_item_port.put(seq_item);
        end
    endtask : run_phase
endclass : serial_data_driver
