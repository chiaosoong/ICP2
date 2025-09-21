module lab_02;

    int result;


    class Packet;
        logic [3:0] non_random;  // Non-random member (not affected by randomize)

        rand logic [3:0] src;
        rand logic [3:0] dest;
        rand logic [7:0] payload [];

        constraint payload_size {payload.size > 0; payload.size < 15;}
        // constraint payload_size_conflict {payload.size == 5;}
    endclass


    class SpecialPacket extends Packet;
        constraint c1 {src inside {[4'h9:4'hc]};}
        constraint c2 {dest inside {[0:8]}; }
        constraint payload_size {payload.size >= 15; payload.size < 20;}
        constraint c3 {foreach (payload[i]) { (payload[i]) > 'hbb;} }
    endclass


    class Bus;
        rand logic [15:0] addr;
        rand logic [31:0] data;

        constraint address_rule {addr[7:0] == 'h01;}
        constraint data_rule1 {data[15:0] == 'hffff;}
        constraint data_rule2 {data[31:16] > 'hafff;}
    endclass


    class CylicIntro;
        rand logic [2:0] d_normal;
        randc logic [2:0] d_cylic;
    endclass


    class PrePostRandomization;
        rand logic [2:0] data;

        function void pre_randomize();
            $display("Pre randomiztion data = %d", data);
        endfunction

        function void post_randomize();
            $display("Post randomiztion data = %d", data);
        endfunction
    endclass


    class Test1;
        task run;
            Packet packet;
            packet = new();

            repeat(8) begin
                result = packet.randomize;  // The same as packet.randomize();
                $displayh("%p", packet);
            end
            $display("");
        endtask;
    endclass: Test1


    class Test2;
        task run;
            SpecialPacket packet;
            packet = new();

            repeat(8) begin
                result = packet.randomize();
                $displayh("%p", packet);
            end
            $display("");
        endtask;
    endclass: Test2


    class Test3;
        task run;
            Bus bus;
            bus = new();

            repeat(8) begin
                result = bus.randomize();
                $displayh("%p", bus);
            end
            $display("");
        endtask;
    endclass: Test3


    class Test4;
        task run;
            Bus bus;
            bus = new();

            bus.data_rule1.constraint_mode(0);  // Turn constraint off
            bus.data_rule2.constraint_mode(0);  // Turn constraint off
            
            repeat(4) begin
                result = bus.randomize();
                $displayh("%p", bus);
            end

            bus.data_rule1.constraint_mode(1);  // Turn constraint back on

            repeat(4) begin
                result = bus.randomize();
                $displayh("%p", bus);
            end
            $display("");
        endtask;
    endclass: Test4


    class Test5;
        task run;
            CylicIntro c;
            c = new();

            repeat(16) begin
                result = c.randomize();
                $displayh("%p", c);
            end
            $display("");
        endtask;
    endclass: Test5


    class Test6;
        task run;
            PrePostRandomization ppr;
            ppr = new();
            result = ppr.randomize();
            result = ppr.randomize();
            $display("");
        endtask
    endclass: Test6


    initial begin
        Test1 test1;
        Test2 test2;
        Test3 test3;
        Test4 test4;
        Test5 test5;
        Test6 test6;


        test1 = new();
        test1.run();        

        test2 = new();
        test2.run();

        test3 = new();
        test3.run();

        test4 = new();
        test4.run();

        test5 = new();
        test5.run();

        test6 = new();
        test6.run();

        // Task 1
        // Uncomment the line in the "Packet" class containing the "payload_size_conflict" constraint and see what transpires. What on earth is happening?

        // Task 2
        // Create a class named "Task2" and in its "run" task call "randomize" in a way to only apply randomization to "src" and "payload" members of "Packet"

        // Task 3
        // Create a class named "MyBus" that extends "Bus" and change its "address_rule" so that "addr[7:0]" can not be 8'hff and also not in the range 8'h11:8'h77
        // Randomize and test "MyBus" in a new class named "Task3", but turn off "data_rule1"

    end

endmodule
