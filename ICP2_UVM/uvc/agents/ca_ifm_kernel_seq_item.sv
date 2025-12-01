// Lightweight sequence item used by the CA monitor and scoreboar
class ca_ifm_kernel_seq_item extends uvm_sequence_item;
    `uvm_object_utils(ca_ifm_kernel_seq_item)

    // 3 lanes of IFM (one byte each) as seen by CA for a single patch element
    bit [`DATA_WIDTH-1:0] ifm_lane [2:0];

    // Flag: 1 == this item represents kernel load, 0 == IFM patch
    bit is_kernel;

    // Timestamp for ordering
    longint unsigned time_stamp;

    function new(string name = "ca_ifm_kernel_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("CA_ITEM: kernel=%0d data=[0x%0h,0x%0h,0x%0h] @%0t",
            is_kernel, ifm_lane[0], ifm_lane[1], ifm_lane[2], time_stamp);
    endfunction

endclass
