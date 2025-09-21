module lab_01;

    logic [7:0] data;

    typedef enum logic[2:0] {INIT, START, S1, S2, S3, S4, S5, S6} state_t;
    state_t my_state;

    int result;


    initial begin

        randomize_data();

        randomize_my_state();

        randomize_data_with_constraints();

        randomize_my_state_with_constraints();

        randomize_my_state_with_dist_constraints();

        my_state = S2;
        randomize_data_with_conditional_constraints();

        my_state = INIT;
        randomize_data_with_conditional_constraints();

        // Task 1
        // Create a function that randomizes my_state 16 times in a way that it excludes START from the randomization

        // Task 2
        // Create a function that randomizes data 16 times in a way that it is twice as likely to get data <= 10 than it is to get data >= 200 (and 0 likelihood for 10 < data < 200)

        // Task 3
        // Create a function that randomizes data 16 times in a way that if my_state is [S1:S6] then 50 <= data <= 60 or 100 <= data <= 150, otherwise data <= 20

    end


    function void randomize_data;
        $display("Randomize 'data'");
        repeat(16) begin
            result = randomize(data);
            $display(data);
        end
        $display("");
    endfunction


    function void randomize_my_state;
        $display("Randomize 'my_state'");
        repeat(16) begin
            result = randomize(my_state);
            $display(my_state.name);
        end
        $display("");
    endfunction


    function void randomize_data_with_constraints;
        $display("Randomize 'data' with constraints");
        repeat(16) begin
            result = randomize(data) with { 
                data >= 20; 
                data <= 115; 
            };
            $display(data);
        end
        $display("");
    endfunction


    function void randomize_my_state_with_constraints;
        $display("Randomize 'my_state' with constraints");
        repeat(16) begin
            result = randomize(my_state) with { 
                my_state inside {
                    [INIT:S1], 
                    S3, 
                    S6
                }; 
            };
            $display(my_state.name);
        end
        $display("");
    endfunction


    function void randomize_my_state_with_dist_constraints;
        $display("Randomize 'my_state' with dist constraints");
        repeat(16) begin
            result = randomize(my_state) with { 
                my_state dist {
                    [INIT:S1] := 3, 
                    [S4:S6] := 1
                }; 
            };
            $display(my_state.name);
        end
        $display("");
    endfunction


    function void randomize_data_with_conditional_constraints;
        $display("Randomize 'data' with conditional constraints");
        repeat(16) begin
            result = randomize(data) with { 
                my_state == INIT -> data < 50; 
                my_state == S2 -> data > 100; 
            };
            $display(data);
        end
        $display("");
    endfunction

endmodule
