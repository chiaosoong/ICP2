//Here you can put commonly used definitions!
package tb_pkg;

typedef enum logic[2:0] {
    ADD=0,
    SUB=1,
    MUL=2,
    DIV=3,
    MOD=4
} opcode;

endpackage: tb_pkg