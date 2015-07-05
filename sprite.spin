CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 6_000_000

PUB Main
  cognew(@sprite, 0)

DAT
                        org 0
sprite                  rdbyte tmp, enable_addr        wz
              if_nz     jmp #sprite

                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

lcd_loop                rdbyte tmp, ly_control_addr
                        cmp tmp, ly            wz
              if_nz     cmp tmp, #255          wz
              if_z      jmp #lcd_loop

                        mov ly, tmp            wz
              if_z      mov render_start_addr, framebuffer

start_line              nop

                        rdbyte lcdc, lcdc_addr
                        test lcdc, #$02         wz
              if_z      jmp #end_line

                        mov palette_addr, palette0_addr
                        movd load_palette_line0, #jmp_palette0_line0
                        movd load_palette_line1, #jmp_palette0_line1
                        call #load_palette

                        mov palette_addr, palette1_addr
                        movd load_palette_line0, #jmp_palette1_line0
                        movd load_palette_line1, #jmp_palette1_line1
                        call #load_palette

                        mov read_addr, oam_addr
                        mov write_addr, sprite_buffer0_addr
                        mov line_count, #40
                        mov block_count, #10

                        mov min_y, ly
                        test lcdc, #$04         wz
              if_z      add min_y, #8
                        shl min_y, #24
                        or min_y, y_mask
                        mov max_y, ly
                        add max_y, #16
                        shl max_y, #24
                        or max_y, y_mask

read_loop               rdlong tmp, read_addr

                        add read_addr, #4
                        ror tmp, #8
                        cmp tmp, min_y         wc,wz
              if_a      cmp max_y, tmp         wc,wz
              if_be     jmp #read_loop_end

                        sub write_addr, #4
                        wrlong tmp, write_addr
                        cmp write_addr, sprite_addr     wz
read_loop_end if_nz     djnz block_count, #read_loop

                        shr min_y, #24

sprite_read             cmp write_addr, sprite_buffer0_addr wz
              if_z      jmp #end_line

                        rdword x, write_addr
                        add write_addr, #2
                        mov tile, x

                        rdword flags, write_addr
                        add write_addr, #2
                        mov y, flags

                        shr tile, #8
                        and x, #$FF
                        shr y, #8
                        and flags, #$FF

                        sub y, min_y

                        test lcdc, #$04         wz
              if_z      jmp #no_adj_tile
                        cmpsub y, #8            wc
              if_ae     or tile, #1
              if_b      and tile, #$FE

no_adj_tile             test flags, #$40        wz
              if_z      neg y, y
              if_z      add y, #8
              if_nz     sub y, #1
                        shl y, #1

                        shl tile, #4
                        add tile, y
                        add tile, sprite_tile_addr

                        rdword work0, tile
                        mov work1, work0
                        and work0, #$FF
                        shr work1, #8

                        test flags, #$20        wz
              if_nz     rev work0, #24
              if_nz     rev work1, #24

                        mov sprite_0_data, work0
                        or sprite_0_data, work1

                        test flags, #$10        wz
              if_z      call #palette0
              if_nz     call #palette1

                        test flags, #$80        wz
                        muxz sprite_fg_data, #$FF
                        and sprite_fg_data, sprite_0_data

                        mov shift, x
                        and shift, #15

                        cmp x, #168             wc
              if_ae     jmp #end_sprite

                        cmp shift, #8           wc
              if_ae     jmp #second_block
                        cmp x, #8               wc
              if_b      jmp #second_block

                        mov line0, data0
                        shr line0, shift
                        mov line1, data1
                        shr line1, shift
                        mov sprite_0_work, sprite_0_data
                        shr sprite_0_work, shift
                        mov sprite_fg_work, sprite_fg_data
                        shr sprite_fg_work, shift
                        mov x_work, x
                        sub x_work, #8
                        shr x_work, #4

                        call #do_block

second_block            cmp shift, #0           wz
                        cmp x, #161             wc
              if_z_or_nc jmp #end_sprite

                        neg shift, shift
                        add shift, #16

                        mov line0, data0
                        shl line0, shift
                        mov line1, data1
                        shl line1, shift
                        mov sprite_0_work, sprite_0_data
                        shl sprite_0_work, shift
                        mov sprite_fg_work, sprite_fg_data
                        shl sprite_fg_work, shift
                        mov x_work, x
                        shr x_work, #4

                        call #do_block

end_sprite              jmp #sprite_read

end_line                jmp #lcd_loop


do_block                shl x_work, #1
                        mov sprite_buffer0_block, sprite_buffer0_addr
                        add sprite_buffer0_block, x_work
                        rdword sprite_buffer0, sprite_buffer0_block

                        mov sprite_buffer1_block, sprite_buffer1_addr
                        add sprite_buffer1_block, x_work
                        rdword sprite_buffer1, sprite_buffer1_block

                        mov sprite_0_buffer_block, sprite_0_buffer_addr
                        add sprite_0_buffer_block, x_work
                        rdword sprite_0_buffer, sprite_0_buffer_block

                        mov sprite_fg_buffer_block, sprite_fg_buffer_addr
                        add sprite_fg_buffer_block, x_work
                        rdword sprite_fg_buffer, sprite_fg_buffer_block

                        andn sprite_buffer0, sprite_0_work
                        or sprite_buffer0, line0
                        wrword sprite_buffer0, sprite_buffer0_block

                        andn sprite_buffer1, sprite_0_work
                        or sprite_buffer1, line1
                        wrword sprite_buffer1, sprite_buffer1_block

                        or sprite_0_buffer, sprite_0_work
                        wrword sprite_0_buffer, sprite_0_buffer_block

                        or sprite_fg_buffer, sprite_fg_work
                        wrword sprite_fg_buffer, sprite_fg_buffer_block
do_block_ret            ret

palette0                mov palette_done, #palette0_line0_done
jmp_palette0_line0      jmp #palette
palette0_line0_done     mov data0, palette_out
                        mov palette_done, #palette0_line1_done
jmp_palette0_line1      jmp #palette
palette0_line1_done     mov data1, palette_out
palette0_ret            ret

palette1                mov palette_done, #palette1_line0_done
jmp_palette1_line0      jmp #palette
palette1_line0_done     mov data0, palette_out
                        mov palette_done, #palette1_line1_done
jmp_palette1_line1      jmp #palette
palette1_line1_done     mov data1, palette_out
palette1_ret            ret

load_palette            rdbyte work0, palette_addr
                        mov work1, work0
                        mov line0, work0
                        mov line1, work0

                        and work0, #$05
                        and line0, #$50
                        shr line0, #3
                        or work0, line0
                        shl work0, #2
                        add work0, #palette
load_palette_line0      movs jmp_palette0_line0, work0

                        and work1, #$0A
                        and line1, #$A0
                        shr work1, #1
                        shr line1, #4
                        or work1, line1
                        shl work1, #2
                        add work1, #palette
load_palette_line1      movs jmp_palette0_line1, work1
load_palette_ret        ret

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

read_addr               long 0
write_addr              long 0
oam_addr                long $3E00
sprite_addr             long $3AFC
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

x                       long 0
y                       long 0
tile                    long 0
flags                   long 0
shift                   long 0
min_y                   long 0
max_y                   long 0
y_mask                  long $00FFFFFF
x_tile                  long 0
x_pixel                 long 0
x_pixel_8               long 0
y_pixel                 long 0
sprite_tile_addr        long $6000
addr                    long 0
work0                   long 0
work1                   long 0
tmp                     long 0
sprite_0_work           long 0
sprite_fg_work          long 0
x_work                  long 0
sprite_0_data           long 0
sprite_fg_data          long 0
line0                   long 0
line1                   long 0
data0                   long 0
data1                   long 0
leftover0               long 0
leftover1               long 0
block_count             long 0
line_count              long 0
ly_control_addr         long $3DE8

framebuffer             long $2440
render_start_addr       long 0
render_addr             long 0
bg_buffer0_addr         long $3AC0
bg_buffer0              long 0
bg_buffer1_addr         long $3AD4
bg_buffer1              long 0
bg_0_buffer_addr        long $3AE8
bg_0_buffer             long 0

b0                      long $55555555
b1                      long $33333333
b2                      long $0F0F0F0F
b3                      long $00FF00FF

lcdc                    long 0
lcdc_addr               long $3F40
ly                      long 255

palette0_addr           long $3F48
palette1_addr           long $3F49
palette_addr            long 0
palette_out             long 0
palette_done            long 0
all1                    long $FFFFFFFF

scy                     long 0
scx                     long 0
scyx_addr               long $3F42

mailbox_long            long $3DF4

