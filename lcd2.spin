CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 6_000_000

PUB Main
  cognew(@lcd, 0)

DAT
                        org 0
lcd                     rdbyte tmp, enable_addr         wz
              if_nz     jmp #lcd

                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

lcd_loop                mov bg_buffer0, bg_buffer0_addr
                        mov bg_buffer1, bg_buffer1_addr
                        mov bg_0_buffer, bg_0_buffer_addr

                        rdbyte work0, ly_control_addr
                        cmp work0, ly           wz
              if_nz     cmp work0, #255         wz
              if_z      jmp #lcd_loop

                        mov ly, work0           wz
              if_z      mov render_start_addr, framebuffer
              if_z      mov w_line, #0

start_line              mov render_addr, render_start_addr
                        mov sync_cnt, cnt
                        add sync_cnt, sync_delay

                        mov work1, #20
                        mov work0, sprite_buffer0_addr
                        mov tmp, #0
clear_loop              wrlong tmp, work0
                        add work0, #4
                        djnz work1, #clear_loop

                        rdbyte lcdc, lcdc_addr
                        test lcdc, #$01         wz
              if_z      jmp #no_bg

                        rdbyte work0, palette_addr
                        mov work1, work0
                        mov line0, work0
                        mov line1, work0

                        and work0, #$05
                        and line0, #$50
                        shr line0, #3
                        or work0, line0
                        shl work0, #2
                        add work0, #palette
                        movs jmp_palette_line0, work0

                        and work1, #$0A
                        and line1, #$A0
                        shr work1, #1
                        shr line1, #4
                        or work1, line1
                        shl work1, #2
                        add work1, #palette
                        movs jmp_palette_line1, work1

                        rdword scy, scyx_addr
                        mov scx, scy
                        shr scx, #8
                        and scx, #$FF
                        add scy, ly
                        and scy, #$FF

                        mov x_tile, scx
                        shr x_tile, #3
                        mov x_pixel, scx
                        and x_pixel, #$7
                        neg x_pixel_8, x_pixel
                        add x_pixel_8, #8

                        mov y_pixel, scy
                        and y_pixel, #$7
                        shl y_pixel, #1

                        mov tile_map_addr, scy
                        shr tile_map_addr, #3
                        shl tile_map_addr, #5
                        add tile_map_addr, x_tile

                        test lcdc, #$08         wz
              if_z      add tile_map_addr, tile_map_0
              if_nz     add tile_map_addr, tile_map_1

                        jmpret read_tile_line_ret, #read_tile_line_no_inc
                        mov work0, line0
                        mov work1, line1

                        rdword wy, wyx_addr
                        mov wx, wy
                        shr wx, #8
                        and wy, #$FF

                        test lcdc, #$20         wz
              if_z      jmp #no_window
                        cmp ly, wy              wc
              if_b      jmp #no_window
                        cmp wx, #167            wc
              if_ae     jmp #no_window

                        mov window_block, wx
                        min window_block, #7
                        sub window_block, #7
                        shr window_block, #5
                        neg window_block, window_block
                        add window_block, #5

no_window               mov block_count, #5

block_loop              mov line_count, #3
                        call #line_loop

                        cmp block_count, window_block   wz
              if_z      call #setup_window

                        rev work0, #0
                        rev work1, #0

                        mov bg_0_work, work0
                        or bg_0_work, work1
                        wrlong bg_0_work, bg_0_buffer

                        mov palette_done, #palette_line0_done
jmp_palette_line0       jmp #palette
palette_line0_done      mov line0, palette_out
                        mov palette_done, #palette_line1_done
jmp_palette_line1       jmp #palette
palette_line1_done      mov line1, palette_out

                        wrlong line0, bg_buffer0
                        mov work0, leftover0
                        mov work1, leftover1
                        wrlong line1, bg_buffer1

                        add bg_buffer0, #4
                        add bg_buffer1, #4
                        add bg_0_buffer, #4

                        djnz block_count, #block_loop

                        jmp #end_line

no_bg                   mov tmp, #0
                        mov line_count, #15
no_bg_loop              wrlong tmp, bg_buffer0
                        add bg_buffer0, #4
                        djnz line_count, #no_bg_loop

end_line                mov line_count, #10
                        mov bg_buffer0, bg_buffer0_addr
                        mov bg_buffer1, bg_buffer1_addr
                        mov bg_0_buffer, bg_0_buffer_addr
                        mov sprite_buffer0, sprite_buffer0_addr
                        mov sprite_buffer1, sprite_buffer1_addr
                        mov sprite_0_buffer, sprite_0_buffer_addr
                        mov sprite_fg_buffer, sprite_fg_buffer_addr

                        waitcnt sync_cnt, #0

mix_loop                rdword bg_0_work, bg_0_buffer
                        add bg_0_buffer, #2
                        xor bg_0_work, all1
                        rdword sprite_fg_buffer_block, sprite_fg_buffer
                        rev sprite_fg_buffer_block, #16
                        or sprite_fg_buffer_block, bg_0_work
                        rdword sprite_0_buffer_block, sprite_0_buffer
                        rev sprite_0_buffer_block, #16
                        and sprite_0_buffer_block, sprite_fg_buffer_block

                        rdword sprite_buffer0_block, sprite_buffer0
                        rev sprite_buffer0_block, #16
                        and sprite_buffer0_block, sprite_0_buffer_block
                        rdword sprite_buffer1_block, sprite_buffer1
                        rev sprite_buffer1_block, #16
                        and sprite_buffer1_block, sprite_0_buffer_block

                        rdword line0, bg_buffer0
                        add bg_buffer0, #2
                        andn line0, sprite_0_buffer_block
                        rdword line1, bg_buffer1
                        add bg_buffer1, #2
                        andn line1, sprite_0_buffer_block

                        add sprite_fg_buffer, #2
                        add sprite_0_buffer, #2
                        add sprite_buffer0, #2
                        add sprite_buffer1, #2

                        or line0, sprite_buffer0_block
                        or line1, sprite_buffer1_block

                        mov tmp, line0
                        shl tmp, #8
                        or line0, tmp
                        and line0, b3

                        mov tmp, line0
                        shl tmp, #4
                        or line0, tmp
                        and line0, b2

                        mov tmp, line0
                        shl tmp, #2
                        or line0, tmp
                        and line0, b1

                        mov tmp, line0
                        shl tmp, #1
                        or line0, tmp
                        and line0, b0

                        mov tmp, line1
                        shl tmp, #8
                        or line1, tmp
                        and line1, b3

                        mov tmp, line1
                        shl tmp, #4
                        or line1, tmp
                        and line1, b2

                        mov tmp, line1
                        shl tmp, #2
                        or line1, tmp
                        and line1, b1

                        mov tmp, line1
                        shl tmp, #1
                        or line1, tmp
                        and line1, b0

                        shl line1, #1
                        or line0, line1

                        wrlong line0, render_addr
                        add render_addr, #4
                        djnz line_count, #mix_loop

                        add render_start_addr, #40
                        jmp #lcd_loop


read_tile_line          add tile_map_addr, #1
                        test tile_map_addr, #$1F        wz
              if_z      sub tile_map_addr, #32
read_tile_line_no_inc   rdbyte addr, tile_map_addr

                        test lcdc, #$10         wz
               if_z     jmp #do_tile_data_0
                        shl addr, #4
                        add addr, tile_data_1
                        jmp #read_tile_line_finish

do_tile_data_0          shl addr, #24
                        sar addr, #24
                        shl addr, #4
                        add addr, tile_data_0

read_tile_line_finish   add addr, y_pixel
                        rdword line0, addr
                        mov line1, line0
                        and line0, #$FF
                        shr line1, #8

read_tile_line_ret      ret


line_loop               shl work0, #8
                        shl work1, #8
                        call #read_tile_line
                        or work0, line0
                        or work1, line1
                        djnz line_count, #line_loop

                        call #read_tile_line
line_loop_leftover      mov leftover0, line0
                        mov leftover1, line1

                        shl work0, x_pixel
                        shl work1, x_pixel
                        shr line0, x_pixel_8
                        shr line1, x_pixel_8
                        or work0, line0
                        or work1, line1
line_loop_ret           ret


setup_window            mov window_block, #0
                        mov w_buffer0, work0
                        mov w_buffer1, work1

                        mov y_pixel, w_line
                        and y_pixel, #$7
                        shl y_pixel, #1

                        mov tile_map_addr, w_line
                        shr tile_map_addr, #3
                        shl tile_map_addr, #5

                        test lcdc, #$40         wz
              if_z      add tile_map_addr, tile_map_0
              if_nz     add tile_map_addr, tile_map_1

                        jmpret read_tile_line_ret, #read_tile_line_no_inc

                        min wx, #7              wc
                        sub wx, #7
                        mov x_pixel, wx
                        and x_pixel, #$7
                        neg x_pixel_8, x_pixel
                        add x_pixel_8, #8

                        and wx, #31
                        mov line_count, #31
                        sub line_count, wx
                        shr line_count, #3
                        addx line_count, #0     wz
              if_z      jmpret line_loop_ret, #line_loop_leftover
              if_z      jmp #no_line_loop

                        mov work0, line0
                        mov work1, line1
                        call #line_loop

no_line_loop            mov tmp, all1
                        shr tmp, wx
                        and work0, tmp
                        and work1, tmp
                        andn w_buffer0, tmp
                        andn w_buffer1, tmp
                        or work0, w_buffer0
                        or work1, w_buffer1

                        add w_line, #1
setup_window_ret        ret

                        ' 0000 (-)
palette                 mov palette_out, #0
                        nop
                        nop
                        jmp palette_done

                        ' 0001 (0)
                        mov palette_out, work0
                        or palette_out, work1
                        xor palette_out, all1
                        jmp palette_done

                        ' 0010 (2)
                        mov palette_out, work1
                        andn palette_out, work0
                        nop
                        jmp palette_done

                        ' 0011 (0,2)
                        mov palette_out, work0
                        xor palette_out, all1
                        nop
                        jmp palette_done

                        ' 0100 (1)
                        mov palette_out, work0
                        andn palette_out, work1
                        nop
                        jmp palette_done

                        ' 0101 (0,1)
                        mov palette_out, work1
                        xor palette_out, all1
                        nop
                        jmp palette_done

                        ' 0110 (1,2)
                        mov palette_out, work0
                        xor palette_out, work1
                        nop
                        jmp palette_done

                        ' 0111 (0,1,2)
                        mov palette_out, work0
                        and palette_out, work1
                        xor palette_out, all1
                        jmp palette_done

                        ' 1000 (3)
                        mov palette_out, work0
                        and palette_out, work1
                        nop
                        jmp palette_done

                        ' 1001 (0,3)
                        mov palette_out, work0
                        xor palette_out, work1
                        xor palette_out, all1
                        jmp palette_done

                        ' 1010 (2,3)
                        mov palette_out, work1
                        nop
                        nop
                        jmp palette_done

                        ' 1011 (0,2,3)
                        mov palette_out, work0
                        andn palette_out, work1
                        xor palette_out, all1
                        jmp palette_done

                        ' 1100 (1,3)
                        mov palette_out, work0
                        nop
                        nop
                        jmp palette_done

                        ' 1101 (0,1,3)
                        mov palette_out, work1
                        andn palette_out, work0
                        xor palette_out, all1
                        jmp palette_done

                        ' 1110 (1,2,3)
                        mov palette_out, work0
                        or palette_out, work1
                        nop
                        jmp palette_done

                        ' 1111 (0,1,2,3)
                        mov palette_out, all1
                        nop
                        nop
                        jmp palette_done




enable_addr             long $7FFF

x_tile                  long 0
x_pixel                 long 0
x_pixel_8               long 0
y_pixel                 long 0
tile_map_addr           long 0
tile_map_0              long $7800
tile_map_1              long $7C00
tile_data_0             long $6800
tile_data_1             long $6000
addr                    long 0
work0                   long 0
work1                   long 0
tmp                     long 0
bg_0_work               long 0
line0                   long 0
line1                   long 0
leftover0               long 0
leftover1               long 0
block_count             long 0
line_count              long 0
ly_control_addr         long $3DE8
sync_cnt                long 0
sync_delay              long 6000

framebuffer             long $2440
render_start_addr       long 0
render_addr             long 0
bg_buffer0_addr         long $3AC0
bg_buffer0              long 0
bg_buffer1_addr         long $3AD4
bg_buffer1              long 0
bg_0_buffer_addr        long $3AE8
bg_0_buffer             long 0
sprite_buffer0_addr     long $3B24
sprite_buffer0          long 0
sprite_buffer0_block    long 0
sprite_buffer1_addr     long $3B38
sprite_buffer1          long 0
sprite_buffer1_block    long 0
sprite_0_buffer_addr    long $3B4C
sprite_0_buffer         long 0
sprite_0_buffer_block   long 0
sprite_fg_buffer_addr   long $3B60
sprite_fg_buffer        long 0
sprite_fg_buffer_block  long 0

b0                      long $55555555
b1                      long $33333333
b2                      long $0F0F0F0F
b3                      long $00FF00FF

lcdc                    long 0
lcdc_addr               long $3F40
ly                      long 255

palette_addr            long $3F47
palette_out             long 0
palette_done            long 0
all1                    long $FFFFFFFF

scy                     long 0
scx                     long 0
scyx_addr               long $3F42

wx                      long 0
wy                      long 0
wyx_addr                long $3F4A
w_line                  long 0
window_block            long 0
w_buffer0               long 0
w_buffer1               long 0

mailbox_long            long $3DF4

