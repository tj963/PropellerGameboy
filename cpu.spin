CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 6_000_000

PUB Main
  cognew(@cpu, 0)
  coginit(0, @driver, @cmd_data)

DAT
                        org 0
driver                  mov src, par
copy_loop               rdbyte work_d, src
                        add src, #1
                        wrbyte work_d, dst
                        add dst, #1
                        djnz copy_count, #copy_loop

                        mov work_d, #0
                        mov copy_count, #256
                        mov dst, fill_dst0
clear_loop0             wrbyte work_d, dst
                        add dst, #1
                        djnz copy_count, #clear_loop0

                        mov work_d, #0
                        mov copy_count, #256
                        mov dst, fill_dst1
clear_loop1             wrbyte work_d, dst
                        add dst, #1
                        djnz copy_count, #clear_loop1

                        wrbyte copy_count, enable_addr

                        mov outa, #0
                        mov dira, addr_mask

main_loop               rdbyte stat, stat_addr
                        and stat, #$78
                        rdbyte work_d, stat_lcd_addr
                        and work_d, #$07
                        or stat, work_d
                        wrbyte stat, stat_read_addr

                        mov if_lcd, #0
                        lockclr if_lcd_lock     wc
                        muxc if_lcd, #$01
                        lockclr if_stat_lock    wc
                        muxc if_lcd, #$02
                        lockclr if_timer_lock   wc
                        muxc if_lcd, #$04

                        mov cnt_write_fail, #read_if
                        mov cnt_write_addr, if_addr_d
                        mov cnt_write_wait, #64

read_if                 rdbyte cnt_write_data, cnt_write_addr
                        and cnt_write_data, #$1F
                        or cnt_write_data, if_lcd
                        call #cnt_write

                        rdbyte ie, ie_addr
                        and cnt_write_data, ie  wz
              if_nz     wrlong exec_int_d, interrupt_flag_d
              if_z      wrlong no_int, interrupt_flag_d

                        rdword joyp_data_lo, joyp_data_addr
                        mov joyp_data_hi, joyp_data_lo
                        shr joyp_data_hi, #8

                        mov cnt_write_fail, #read_joyp
                        mov cnt_write_addr, joyp_addr
                        mov cnt_write_wait, #64

read_joyp               rdbyte joyp, joyp_addr
                        mov cnt_write_data, #$3F
                        test joyp, #$20         wz
              if_z      and cnt_write_data, joyp_data_lo
                        test joyp, #$10         wz
              if_z      and cnt_write_data, joyp_data_hi
                        call #cnt_write

                        rdbyte src, dma_src_addr    wz
              if_z      jmp #dma_done

                        wrlong disable_mask, interrupt_flag_d
                        wrlong disable_mask, interrupt_flag_d_disabled

                        mov work_d, cnt
                        add work_d, dma_setup_cnt

                        mov dst, dma_dst_addr
                        mov copy_count, #160
                        waitcnt work_d, #0

                        cmp src, #$80           wc
              if_b      jmp #dma_ext
                        cmp src, #$A0           wc
              if_b      sub src, #$20
              if_b      jmp #dma_int
                        cmp src, #$C0           wc
              if_b      jmp #dma_ext

                        sub src, #$80

dma_int                 shl src, #8
dma_loop_int            rdbyte work_d, src
                        add src, #1
                        wrbyte work_d, dst
                        add dst, #1
                        djnz copy_count, #dma_loop_int
                        jmp #dma_finish

dma_ext                 shl src, #16
                        mov outa, src
dma_loop_ext            nop
                        nop
                        nop
                        nop
                        nop
                        mov work_d, #$FF
                        and work_d, ina
                        add outa, #$100

                        wrbyte work_d, dst
                        add dst, #1
                        djnz copy_count, #dma_loop_int
                        jmp #dma_finish

dma_finish              wrlong enable_mask, interrupt_flag_d
                        wrlong enable_mask, interrupt_flag_d_disabled

                        mov work_d, cnt
                        add work_d, dma_setup_cnt

                        wrbyte copy_count, dma_src_addr
                        waitcnt work_d, #0

dma_done                jmp #main_loop


cnt_write               rdlong write_cnt, write_cnt_addr_d
                        mov check_cnt, cnt
                        sub check_cnt, write_cnt
                        cmp check_cnt, cnt_write_wait wc
              if_c      jmp cnt_write_fail
                        wrbyte cnt_write_data, cnt_write_addr
cnt_write_ret           ret

stat_addr               long $3F41
stat_read_addr          long $3D41
stat_lcd_addr           long $3DC1
stat                    long 0

if_addr_d                 long $3F0F
if_lcd_lock             long 7
if_stat_lock            long 6
if_timer_lock           long 5
if_reg                  long 0
if_lcd                  long 0

joyp_addr               long $3F00
joyp                    long 0
joyp_data_addr          long $3DEC
joyp_data_hi            long 0
joyp_data_lo            long 0

ie_addr                 long $3FFF
ie                      long 0
interrupt_flag_d          long $3DFC
interrupt_flag_d_disabled long $3DF8
exec_int_d                jmp #0
no_int                  long 0

work_d                    long 0
enable_addr             long $7FFF

src                     long 0
dst                     long 0
copy_count              long $2440
fill_dst0               long $3D00
fill_dst1               long $3F00

dma_src_addr            long $3F46
dma_dst_addr            long $3E00
dma_setup_cnt           long 384
disable_mask            mov dira, 1
enable_mask             mov dira, 2
addr_mask               long $00FFFF00

check_cnt               long 0
write_cnt               long 0
write_cnt_addr_d          long $3DF0
cnt_write_fail          long 0
cnt_write_addr          long 0
cnt_write_data          long 0
cnt_write_wait          long 0

mailbox_long_d            long $3DF4
                        fit 496

DAT
                        org 0
cpu                     rdbyte work, enable_addr__cnt   wz
              if_nz     jmp #cpu

                        mov outa, #0
                        wrlong int_check_ext, ints_enabled                      'no_int
                        mov dira, read_mask
                        mov loop_target, #external_loop
                        wrlong int_check_ext, ints_disabled                     'no_int
                        mov 0, exec_int
                        mov 1, no_addr_mask
                        mov 2, read_mask

                        test f, #$10            wc
                        testn z_flag, f         wz

                        '''
                        'mov loop_target, #internal_loop
                        'jmp #internal_loop
                        '''

external_loop           mov outa, pc
                        shl outa, #8
                        muxc f, #$10

                        rdlong int_check_ext, interrupt_flag
                        muxz f, #$80
int_check_ext           nop

                        add pc, #1
                        mov opcode, #$FF
                        and opcode, ina

                        '''
                        'mov opcode, ina
                        'wrlong opcode, mailbox_long
                        'jmp #$
                        '''
'
                        shl opcode, #5

                        rdlong el_ins0, opcode
                        add opcode, #4
el_ins0                 jmp 0

                        rdlong el_ins1, opcode
                        add opcode, #4
el_ins1                 jmp 0

                        rdlong el_ins2, opcode
                        add opcode, #4
el_ins2                 jmp 0

                        jmp loop_target

internal_loop           mov outa, pc
                        shl outa, #8
                        muxc f, #$10

                        rdlong int_check_int, interrupt_flag
                        muxz f, #$80
int_check_int           nop

                        rdbyte opcode, pc
                        add pc, #1
                        shl opcode, #5

                        rdlong il_ins0, opcode
                        add opcode, #4
il_ins0                 jmp 0

                        rdlong il_ins1, opcode
                        add opcode, #4
il_ins1                 jmp 0

                        rdlong il_ins2, opcode
                        add opcode, #4
il_ins2                 jmp 0

finish_loop             jmp loop_target


handle_interrupt        rdbyte work_low, if_addr
                        mov tmp, #1

                        rdbyte work_high, ie_reg
                        and work_high, work_low wz
              if_z      jmp #cancel_interrupt

                        mov interrupt_flag, ints_disabled
                        mov work, #5
interrupt_loop          test work_high, tmp     wz
              if_nz     jmp #interrupt_found
                        shl tmp, #1
                        djnz work, #interrupt_loop

interrupt_found         mov enable_addr__cnt, cnt
                        wrlong enable_addr__cnt, write_cnt_addr
                        andn work_low, tmp
                        wrbyte work_low, if_addr

                        neg work_16, work
                        add work_16, #5
                        shl work_16, #3
                        add work_16, #$40

                        mov opcode, #0
                        jmp #call_work_16

cancel_interrupt        testn z_flag, f         wz
                        jmp loop_target


read_hl_exec_3          mov addr, h
                        shl addr, #8
                        or addr, l
                        mov continue, #exec_3
                        jmp #read_8

read_bc                 mov addr, b
                        shl addr, #8
                        or addr, c
                        mov continue, #exec_3
                        jmp #read_8

read_de                 mov addr, d
                        shl addr, #8
                        or addr, e
                        mov continue, #exec_3
                        jmp #read_8

read_work_io            mov addr, work
                        add addr, io_start
                        nop
                        mov continue, #exec_3
                        jmp #read_8

read_work_16            rdbyte int_check_ext, 0 'NOP
                        mov addr, work_16
                        mov continue, #exec_1
                        jmp #read_8

read_hl_pcb             mov addr, h
                        shl addr, #8
                        or addr, l
                        mov continue, #pcb_istart
                        jmp #read_8


read_8                  cmp io_ram, addr        wc
              if_c      jmp #r8_io_ram
                        mov outa, addr
                        shl outa, #8
                        cmp internal_ram, addr  wc
              if_c      jmp #r8_internal_ram

' External ROM, external SRAM, or VRAM
                        cmp video_ram, addr     wc
              if_c      cmp addr, video_ram_end wc
              if_c      mov tmp, vram_adj
              if_c      jmp #r8_read_int
                        jmp #r8_read_ext

' Internal RAM
r8_internal_ram         mov tmp, ram_adj        wc      ' Clear C
                        rdbyte int_check_ext, 0 'NOP
                        jmp #r8_read_int

r8_read_ext             mov work, #$FF
                        and work, ina
                        test f, #$10            wc
                        jmp continue

' Internal RAM
r8_io_ram               mov tmp, io_ram_adj
                        'nop
                        'nop
                        cmp addr, io_ram_div    wz
              if_nz     cmp addr, io_ram_tima   wz
              if_nz     cmp addr, io_ram_stat   wz
              if_z      sub tmp, io_read_offset
                        testn z_flag, f         wz

r8_read_int             add tmp, addr

                        rdbyte work, tmp
                        test f, #$10            wc
                        jmp continue


read_imm_exec_3         mov continue, #exec_3
                        nop
                        jmp #read_imm

read_imm_exec_2         mov continue, #exec_2
                        nop
                        jmp #read_imm

read_imm_16             mov continue, #read_imm_16_b
                        nop
                        jmp #read_imm
read_imm_16_b           mov work_16, work
                        mov continue, #read_imm_16_c
                        jmp #read_imm
read_imm_16_c           shl work, #8
                        or work_16, work
                        nop
                        jmp #exec_3

read_imm                mov outa, pc
                        shl outa, #8
                        cmp loop_target, #internal_loop  wz

                        rdbyte work, pc
                        'nop
                        'nop
                        rdbyte work, pc
                        nop
                        nop
                        nop

              if_nz     mov work, #$FF
              if_nz     and work, ina
                        add pc, #1

                        testn z_flag, f         wz
                        jmp continue



write_hl_exec_2         mov addr, h
                        shl addr, #8
                        or addr, l
                        mov continue, #exec_2
                        jmp #write_8

write_hl_exec_1         mov addr, h
                        shl addr, #8
                        or addr, l
                        mov continue, #exec_1
                        jmp #write_8

write_hl_inc            mov addr, h
                        shl addr, #8
                        or addr, l
                        mov continue, #inc_hl
                        jmp #write_8

write_hl_dec            mov addr, h
                        shl addr, #8
                        or addr, l
                        mov continue, #dec_hl
                        jmp #write_8

write_bc_exec_2         mov addr, b
                        shl addr, #8
                        or addr, c
                        mov continue, #exec_2
                        jmp #write_8

write_de_exec_2         mov addr, d
                        shl addr, #8
                        or addr, e
                        mov continue, #exec_2
                        jmp #write_8

write_tmp_to_work_io    mov addr, work
                        add addr, io_start
                        mov work, tmp
                        mov continue, #finish_loop
                        jmp #write_8

write_sp_to_work_16     mov addr, work_16
                        mov work, sp
                        and work, #$FF
                        mov continue, #write_sp_to_work_16_b
                        jmp #write_8
write_sp_to_work_16_b   add addr, #1
                        mov work, sp
                        shr work, #8
                        mov continue, #exec_1
                        mov tmp, #5
wstw_wait               nop
                        djnz tmp, #wstw_wait
                        jmp #write_8

write_work_16           rdbyte int_check_ext, 0 'NOP
                        mov addr, work_16
                        mov continue, #exec_1
                        jmp #write_8

write_hl_finish         mov work, #1
                        call #wait_work
                        mov addr, h
                        shl addr, #8
                        or addr, l
                        mov continue, #finish_loop
                        jmp #write_8


write_8                 mov outa, addr
                        shl outa, #8
                        cmp internal_ram, addr  wc
              if_c      jmp #w8_high_addr

' External ROM, external SRAM, or VRAM
                        cmp video_ram, addr     wc
              if_c      cmp addr, video_ram_end wc
              if_nc     jmp #w8_write_ext
                        mov tmp, vram_adj
                        jmp #w8_write_int

w8_write_ext            mov dira, switch_mask
                        or outa, work
                        mov dira, write_mask
                        nop

                        nop
                        test f, #$10            wc
                        mov dira, read_mask
                        jmp continue

w8_write_int            jmp #w8_do_write_int

' Internal RAM or IO
w8_high_addr            cmp io_ram, addr        wc
              if_c      mov tmp, io_ram_adj
              if_c      mov enable_addr__cnt, cnt

                        wrlong enable_addr__cnt, write_cnt_addr
              if_nc     mov tmp, ram_adj
w8_do_write_int         add tmp, addr

                        wrbyte work, tmp
                        test f, #$10            wc
                        jmp continue


inc_hl                  add l, #1
                        test l, #$100           wc
                        and l, #$FF
                        addx h, #0
                        and h, #$FF
                        test f, #$10            wc
                        mov a, work
                        jmp #finish_loop

dec_hl                  sub l, #1               wc
                        and l, #$FF
                        subx h, #0
                        and h, #$FF
                        test f, #$10            wc
                        mov a, work
                        nop
                        jmp #finish_loop

load_hl                 rdbyte int_check_ext, 0 'NOP
                        mov l, work
                        and l, #$FF
                        mov h, work
                        shr h, #8
                        and h, #$FF
                        jmp #finish_loop

sum_sp_r8               shl work, #24
                        sar work, #24
                        mov tmp, sp
                        and tmp, #$FF
                        add tmp, work
                        test tmp, #$100         wc

                        mov work_16, sp
                        add work_16, work
                        rdbyte int_check_ext, 0 'NOP
                        'nop
sum_sp_r8_ret           ret                     wz


exec_1                  rdlong e1_ins0, opcode
                        add opcode, #4
e1_ins0                 jmp 0

                        jmp loop_target


exec_2                  rdlong e2_ins0, opcode
                        add opcode, #4
e2_ins0                 jmp 0

                        rdlong e2_ins1, opcode
                        add opcode, #4
e2_ins1                 jmp 0

                        jmp loop_target


exec_3                  rdlong e3_ins0, opcode
                        add opcode, #4
e3_ins0                 jmp 0

                        rdlong e3_ins1, opcode
                        add opcode, #4
e3_ins1                 jmp 0

                        rdlong e3_ins2, opcode
                        add opcode, #4
e3_ins2                 jmp 0

                        jmp loop_target

exec_7                  rdlong e7_ins0, opcode
                        add opcode, #4
e7_ins0                 jmp 0

                        rdlong e7_ins1, opcode
                        add opcode, #4
e7_ins1                 jmp 0

                        rdlong e7_ins2, opcode
                        add opcode, #4
e7_ins2                 jmp 0

                        rdlong e7_ins3, opcode
                        add opcode, #4
e7_ins3                 jmp 0

                        rdbyte int_check_ext, 0 'NOP
                        nop
                        jmp #exec_3


move_work_16_to_pc      cmp internal_ram, work_16       wc
              if_c      jmp #mwtp_high_addr

' External ROM, external SRAM, or VRAM
                        mov loop_target, #external_loop
                        nop
                        nop
                        jmp #mwtp_end_addr

' Internal RAM or IO
mwtp_high_addr          mov loop_target, #internal_loop
                        cmp io_ram, work_16     wc
              if_c      add work_16, io_ram_adj
              if_nc     add work_16, ram_adj    wc

mwtp_end_addr           mov pc, work_16
move_work_16_to_pc_ret  ret


wait_work               mov tmp, work
ww_wait                 nop
                        djnz tmp, #ww_wait
                        nop
wait_work_ret           ret

wait_8                  mov tmp, #2
wait_8_wait             nop
                        djnz tmp, #wait_8_wait
                        nop
wait_8_ret              ret


call_work_16            nop
                        mov pc_adj, pc
                        cmp loop_target, #internal_loop wz
              if_z      jmp #cw16_internal
                        nop
                        nop
                        jmp #cw16_end_adj

cw16_internal           cmp ram_int, pc         wc
              if_c      sub pc_adj, ram_adj
              if_nc     sub pc_adj, io_ram_adj

cw16_end_adj            testn z_flag, f         wz
                        call #move_work_16_to_pc
                        mov work_16, pc_adj
                        sub sp, #2
                        call #write_work_16_to_sp
                        rdbyte int_check_ext, 0 'NOP
                        test f, #$10            wc
                        jmp loop_target

jmp_work_16             call #move_work_16_to_pc
                        test f, #$10            wc
                        nop
                        jmp #exec_2

' 4 insructions too long
jmp_hl                  mov work_16, h
                        shl work_16, #8
                        add work_16, l
                        call #move_work_16_to_pc
                        nop
                        rdbyte int_check_ext, 0 'NOP
                        test f, #$10            wc
                        jmp loop_target


do_ret                  rdbyte int_check_ext, 0 'NOP
                        nop
                        call #read_sp_to_work_16
                        call #move_work_16_to_pc
                        nop
                        mov work, #1
                        call #wait_work
                        test f, #$10            wc
                        jmp #finish_loop


read_sp_to_work_16      mov addr, sp
                        add sp, #2
                        nop
                        mov continue, #rstw_b
                        jmp #read_8
rstw_b                  add addr, #1
                        mov work_low, work
                        mov work_16, work
                        mov continue, #rstw_c
                        jmp #read_8
rstw_c                  mov work_high, work
                        shl work, #8
                        or work_16, work
read_sp_to_work_16_ret  ret

pop_af                  call #read_sp_to_work_16
                        mov a, work_high
                        mov f, work_low
                        test f, #$10            wc
                        rdbyte int_check_ext, 0 'NOP
                        and f, #$F0
pop_af_ret              jmp #exec_1

write_work_16_to_sp     mov addr, sp
                        mov work, work_16
                        and work, #$FF
                        mov continue, #wwts_work_16_b
                        jmp #write_8
wwts_work_16_b          add addr, #1
                        mov work, work_16
                        shr work, #8
                        mov continue, #wwts_work_16_c
                        jmp #write_8
wwts_work_16_c          rdbyte int_check_ext, 0 'NOP
                        nop
write_work_16_to_sp_ret ret


prefix_cb               mov continue, #prefix_cb_b
                        nop
                        jmp #read_imm
prefix_cb_b             mov work_low, work
                        and work_low, #7
                        shl work_low, #3
                        add work_low, cb_reg_offset

                        mov opcode, work
                        shr opcode, #3
                        shl opcode, #5
                        add opcode, cb_offset

                        rdlong pcb_read, work_low
                        add work_low, #4
pcb_read                jmp 0

pcb_istart              rdlong pcb_i1, opcode
                        add opcode, #4
pcb_i1                  jmp 0

                        rdlong pcb_i2, opcode
                        add opcode, #4
pcb_i2                  jmp 0

                        rdlong pcb_i3, opcode
                        add opcode, #4
pcb_i3                  jmp 0

                        rdlong pcb_i4, opcode
                        add opcode, #4
pcb_i4                  jmp 0

                        rdlong pcb_i5, opcode
                        add opcode, #4
pcb_i5                  jmp 0

                        rdlong pcb_write, work_low
                        nop
pcb_write               jmp 0

                        jmp loop_target


enable_addr__cnt        long $7FFF

a                       long $01
b                       long $00
c                       long $13
d                       long $00
e                       long $D8
h                       long $01
l                       long $4D
f                       long $B0

sp                      long $FFFE
pc                      long $100
'''
'pc                      long $4000
'pc                      long $4000
'''
z_flag                  long $80

cb_offset               long $2000
cb_reg_offset           long $2400
opcode                  long 0
tmp                     long 0
addr                    long 0
pc_adj                  long 0
work                    long 0
work_16                 long 0
work_high               long 0
work_low                long 0

loop_target             long 0
continue                long 0

internal_ram            long $BFFF
io_ram                  long $FDFF
io_ram_adj              long $FFFF4000
ram_adj                 long $FFFF8000
vram_adj                long $FFFFE000
video_ram               long $7FFF
video_ram_end           long $A000
io_start                long $FF00

read_mask               long $80FFFF00
switch_mask             long $00FFFFFF
'write_mask              long $40FFFFFF
write_mask              long $08FFFFFF
no_addr_mask            long $80000000

mask_16                 long $FFFF
mask_16_c               long $10000

ram_int                 long $3FFF
interrupt_flag          long $3DF8
if_addr                 long $3F0F
ie_reg                  long $3FFF

io_ram_div              long $FF04
io_ram_tima             long $FF05
io_ram_stat             long $FF41
io_read_offset          long $0200

write_cnt_addr          long $3DF0
mailbox_long            long $3DF4
ints_disabled           long $3DF8
ints_enabled            long $3DFC

exec_int                jmp #handle_interrupt

                        fit 496

DAT
' 0x00: NOP 1 4
cmd_data                nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x01: LD BC,d16 3 12
                        jmp #read_imm_exec_3
                        mov c, work
                        jmp #read_imm_exec_2
                        mov b, work
                        nop
                        nop
                        nop
                        nop

' 0x02: LD (BC),A 1 8
                        mov work, a
                        jmp #write_bc_exec_2
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x03: INC BC 1 8
                        jmp #exec_7
                        add c, #1
                        test c, #$100           wc
                        and c, #$FF
                        addx b, #0
                        and b, #$FF
                        test f, #$10            wc
                        nop

' 0x04: INC B 1 4
                        add b, #1
                        and b, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x05: DEC B 1 4
                        sub b, #1
                        and b, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x06: LD B,d8 2 8
                        jmp #read_imm_exec_3
                        mov b, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x07: RLCA 1 4
                        test a, #$80            wc
                        rcl a, #1
                        and a, #$FF
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x08: LD (a16),SP 3 20
                        jmp #read_imm_16
                        jmp #write_sp_to_work_16
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x09: ADD HL,BC 1 8
                        jmp #exec_7
                        add l, c
                        test l, #$100           wc
                        and l, #$FF
                        addx h, b
                        test h, #$100           wc
                        and h, #$FF
                        nop

' 0x0a: LD A,(BC) 1 8
                        jmp #read_bc
                        mov a, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x0b: DEC BC 1 8
                        jmp #exec_7
                        sub c, #1               wc
                        and c, #$FF
                        subx b, #0
                        and b, #$FF
                        test f, #$10            wc
                        nop
                        nop

' 0x0c: INC C 1 4
                        add c, #1
                        and c, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x0d: DEC C 1 4
                        sub c, #1
                        and c, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x0e: LD C,d8 2 8
                        jmp #read_imm_exec_3
                        mov c, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x0f: RRCA 1 4
                        shr a, #1               wc
                        muxc a, #$80
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x10: STOP 0 2 4
' This isn't correct.
                        mov interrupt_flag, ints_enabled
                        jmp #exec_3
                        rdlong work, interrupt_flag
                        cmp work, #0            wz
                        jmp #exec_2
                        sub opcode, #16
              if_z      jmp #exec_3
                        nop

' 0x11: LD DE,d16 3 12
                        jmp #read_imm_exec_3
                        mov e, work
                        jmp #read_imm_exec_2
                        mov d, work
                        nop
                        nop
                        nop
                        nop

' 0x12: LD (DE),A 1 8
                        mov work, a
                        jmp #write_de_exec_2
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x13: INC DE 1 8
                        jmp #exec_7
                        add e, #1
                        test e, #$100           wc
                        and e, #$FF
                        addx d, #0
                        and d, #$FF
                        test f, #$10            wc
                        nop

' 0x14: INC D 1 4
                        add d, #1
                        and d, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x15: DEC D 1 4
                        sub d, #1
                        and d, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x16: LD D,d8 2 8
                        jmp #read_imm_exec_3
                        mov d, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x17: RLA 1 4
                        rcl a, #1
                        test a, #$100           wc
                        and a, #$FF
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x18: JR r8 2 12
                        jmp #read_imm_exec_3
                        shl work, #24
                        sar work, #24
                        jmp #exec_3
                        add pc, work
                        mov work, #4
                        call #wait_work
                        nop

' 0x19: ADD HL,DE 1 8
                        jmp #exec_7
                        add l, e
                        test l, #$100           wc
                        and l, #$FF
                        addx h, d
                        test h, #$100           wc
                        and h, #$FF
                        nop

' 0x1a: LD A,(DE) 1 8
                        jmp #read_de
                        mov a, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x1b: DEC DE 1 8
                        jmp #exec_7
                        sub e, #1               wc
                        and e, #$FF
                        subx d, #0
                        and d, #$FF
                        test f, #$10            wc
                        nop
                        nop

' 0x1c: INC E 1 4
                        add e, #1
                        and e, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x1d: DEC E 1 4
                        sub e, #1
                        and e, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x1e: LD E,d8 2 8
                        jmp #read_imm_exec_3
                        mov e, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x1f: RRA 1 4
                        muxc a, #$100
                        shr a, #1               wc
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x20: JR NZ,r8 2 12/8
                        jmp #read_imm_exec_3
                        shl work, #24
                        testn z_flag, f         wz
              if_nz     jmp #exec_2
                        sar work, #24
                        jmp #exec_2
                        add pc, work
                        call #wait_8

' 0x21: LD HL,d16 3 12
                        jmp #read_imm_exec_3
                        mov l, work
                        jmp #read_imm_exec_2
                        mov h, work
                        nop
                        nop
                        nop
                        nop

' 0x22: LD (HL+),A 1 8
                        mov work, a
                        jmp #write_hl_inc
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x23: INC HL 1 8
                        jmp #exec_7
                        add l, #1
                        test l, #$100           wc
                        and l, #$FF
                        addx h, #0
                        and h, #$FF
                        test f, #$10            wc
                        nop

' 0x24: INC H 1 4
                        add h, #1
                        and h, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x25: DEC H 1 4
                        sub h, #1
                        and h, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x26: LD H,d8 2 8
                        jmp #read_imm_exec_3
                        mov h, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x27: DAA 1 4
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x28: JR Z,r8 2 12/8
                        jmp #read_imm_exec_3
                        shl work, #24
                        testn z_flag, f         wz
              if_z      jmp #exec_2
                        sar work, #24
                        jmp #exec_2
                        add pc, work
                        call #wait_8

' 0x29: ADD HL,HL 1 8
                        jmp #exec_7
                        add l, l
                        test l, #$100           wc
                        and l, #$FF
                        addx h, h
                        test h, #$100           wc
                        and h, #$FF
                        nop

' 0x2a: LD A,(HL+) 1 8
                        jmp #read_hl_exec_3
                        jmp #inc_hl
                        jmp #finish_loop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x2b: DEC HL 1 8
                        jmp #exec_7
                        sub l, #1               wc
                        and l, #$FF
                        subx h, #0
                        and h, #$FF
                        test f, #$10            wc
                        nop
                        nop

' 0x2c: INC L 1 4
                        add l, #1
                        and l, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x2d: DEC L 1 4
                        sub l, #1
                        and l, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x2e: LD L,d8 2 8
                        jmp #read_imm_exec_3
                        mov l, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x2f: CPL 1 4
                        xor a, #$FF
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x30: JR NC,r8 2 12/8
                        jmp #read_imm_exec_3
                        shl work, #24
                        jmp #exec_3
              if_c      jmp #finish_loop
                        sar work, #24
                        jmp #exec_2
                        add pc, work
                        call #wait_8

' 0x31: LD SP,d16 3 12
                        jmp #read_imm_exec_3
                        mov sp, work
                        jmp #read_imm_exec_2
                        shl work, #8
                        or sp, work
                        nop
                        nop
                        nop

' 0x32: LD (HL-),A 1 8
                        mov work, a
                        jmp #write_hl_dec
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x33: INC SP 1 8
                        jmp #exec_7
                        add sp, #1
                        and sp, #mask_16
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x34: INC (HL) 1 12
                        jmp #read_hl_exec_3
                        add work, #1
                        and work, #$FF          wz
                        jmp #write_hl_exec_1
                        nop
                        nop
                        nop
                        nop

' 0x35: DEC (HL) 1 12
                        jmp #read_hl_exec_3
                        sub work, #1
                        and work, #$FF          wz
                        jmp #write_hl_exec_1
                        nop
                        nop
                        nop
                        nop

' 0x36: LD (HL),d8 2 12
                        jmp #read_imm_exec_3
                        nop
                        nop
                        jmp #write_hl_exec_1
                        nop
                        nop
                        nop
                        nop

' 0x37: SCF 1 4
                        mov work, #1
                        ror work, #1            wc
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x38: JR C,r8 2 12/8
                        jmp #read_imm_exec_3
                        shl work, #24
                        jmp #exec_3
              if_nc     jmp #finish_loop
                        sar work, #24
                        jmp #exec_2
                        add pc, work
                        call #wait_8

' 0x39: ADD HL,SP 1 8
                        jmp #exec_7
                        mov work, h
                        shl work, #8
                        add work, l
                        add work, sp
                        test work, mask_16_c    wc
                        jmp #load_hl
                        nop

' 0x3a: LD A,(HL-) 1 8
                        jmp #read_hl_exec_3
                        jmp #dec_hl
                        jmp #finish_loop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x3b: DEC SP 1 8
                        jmp #exec_7
                        sub sp, #1              wc
                        and sp, mask_16
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x3c: INC A 1 4
                        add a, #1
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x3d: DEC A 1 4
                        sub a, #1
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x3e: LD A,d8 2 8
                        jmp #read_imm_exec_3
                        mov a, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x3f: CCF 1 4
                        mov work, #1
                        addx work, #0
                        ror work, #1            wc
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x40: LD B,B 1 4
                        mov b, b
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x41: LD B,C 1 4
                        mov b, c
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x42: LD B,D 1 4
                        mov b, d
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x43: LD B,E 1 4
                        mov b, e
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x44: LD B,H 1 4
                        mov b, h
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x45: LD B,L 1 4
                        mov b, l
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x46: LD B,(HL) 1 8
                        jmp #read_hl_exec_3
                        mov b, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x47: LD B,A 1 4
                        mov b, a
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x48: LD C,B 1 4
                        mov c, b
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x49: LD C,C 1 4
                        mov c, c
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x4a: LD C,D 1 4
                        mov c, d
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x4b: LD C,E 1 4
                        mov c, e
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x4c: LD C,H 1 4
                        mov c, h
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x4d: LD C,L 1 4
                        mov c, l
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x4e: LD C,(HL) 1 8
                        jmp #read_hl_exec_3
                        mov c, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x4f: LD C,A 1 4
                        mov c, a
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x50: LD D,B 1 4
                        mov d, b
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x51: LD D,C 1 4
                        mov d, c
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x52: LD D,D 1 4
                        mov d, d
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x53: LD D,E 1 4
                        mov d, e
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x54: LD D,H 1 4
                        mov d, h
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x55: LD D,L 1 4
                        mov d, l
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x56: LD D,(HL) 1 8
                        jmp #read_hl_exec_3
                        mov d, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x57: LD D,A 1 4
                        mov d, a
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x58: LD E,B 1 4
                        mov e, b
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x59: LD E,C 1 4
                        mov e, c
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x5a: LD E,D 1 4
                        mov e, d
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x5b: LD E,E 1 4
                        mov e, e
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x5c: LD E,H 1 4
                        mov e, h
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x5d: LD E,L 1 4
                        mov e, l
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x5e: LD E,(HL) 1 8
                        jmp #read_hl_exec_3
                        mov e, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x5f: LD E,A 1 4
                        mov e, a
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x60: LD H,B 1 4
                        mov h, b
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x61: LD H,C 1 4
                        mov h, c
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x62: LD H,D 1 4
                        mov h, d
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x63: LD H,E 1 4
                        mov h, e
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x64: LD H,H 1 4
                        mov h, h
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x65: LD H,L 1 4
                        mov h, l
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x66: LD H,(HL) 1 8
                        jmp #read_hl_exec_3
                        mov h, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x67: LD H,A 1 4
                        mov h, a
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x68: LD L,B 1 4
                        mov l, b
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x69: LD L,C 1 4
                        mov l, c
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x6a: LD L,D 1 4
                        mov l, d
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x6b: LD L,E 1 4
                        mov l, e
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x6c: LD L,H 1 4
                        mov l, h
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x6d: LD L,L 1 4
                        mov l, l
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x6e: LD L,(HL) 1 8
                        jmp #read_hl_exec_3
                        mov l, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x6f: LD L,A 1 4
                        mov l, a
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x70: LD (HL),B 1 8
                        mov work, b
                        jmp #write_hl_exec_2
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x71: LD (HL),C 1 8
                        mov work, c
                        jmp #write_hl_exec_2
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x72: LD (HL),D 1 8
                        mov work, d
                        jmp #write_hl_exec_2
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x73: LD (HL),E 1 8
                        mov work, e
                        jmp #write_hl_exec_2
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x74: LD (HL),H 1 8
                        mov work, h
                        jmp #write_hl_exec_2
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x75: LD (HL),L 1 8
                        mov work, l
                        jmp #write_hl_exec_2
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x76: HALT 1 4
                        cmp interrupt_flag, ints_enabled                        wz
              if_nz     jmp #finish_loop
                        jmp #exec_3
                        rdlong work, interrupt_flag
                        cmp work, #0            wz
                        jmp #exec_2
                        sub opcode, #16
              if_z      jmp #exec_3

' 0x77: LD (HL),A 1 8
                        mov work, a
                        jmp #write_hl_exec_2
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x78: LD A,B 1 4
                        mov a, b
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x79: LD A,C 1 4
                        mov a, c
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x7a: LD A,D 1 4
                        mov a, d
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x7b: LD A,E 1 4
                        mov a, e
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x7c: LD A,H 1 4
                        mov a, h
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x7d: LD A,L 1 4
                        mov a, l
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x7e: LD A,(HL) 1 8
                        jmp #read_hl_exec_3
                        mov a, work
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x7f: LD A,A 1 4
                        mov a, a
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x80: ADD A,B 1 4
                        add a, b
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x81: ADD A,C 1 4
                        add a, c
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x82: ADD A,D 1 4
                        add a, d
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x83: ADD A,E 1 4
                        add a, e
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x84: ADD A,H 1 4
                        add a, h
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x85: ADD A,L 1 4
                        add a, l
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x86: ADD A,(HL) 1 8
                        jmp #read_hl_exec_3
                        add a, work
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop

' 0x87: ADD A,A 1 4
                        add a, a
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x88: ADC A,B 1 4
                        addx a, b
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x89: ADC A,C 1 4
                        addx a, c
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x8a: ADC A,D 1 4
                        addx a, d
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x8b: ADC A,E 1 4
                        addx a, e
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x8c: ADC A,H 1 4
                        addx a, h
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x8d: ADC A,L 1 4
                        addx a, l
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x8e: ADC A,(HL) 1 8
                        jmp #read_hl_exec_3
                        addx a, work
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop

' 0x8f: ADC A,A 1 4
                        addx a, a
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x90: SUB B 1 4
                        sub a, b                wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x91: SUB C 1 4
                        sub a, c                wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x92: SUB D 1 4
                        sub a, d                wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x93: SUB E 1 4
                        sub a, e                wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x94: SUB H 1 4
                        sub a, h                wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x95: SUB L 1 4
                        sub a, l                wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x96: SUB (HL) 1 8
                        jmp #read_hl_exec_3
                        sub a, work
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x97: SUB A 1 4
                        sub a, a                wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x98: SBC A,B 1 4
                        subx a, b               wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x99: SBC A,C 1 4
                        subx a, c               wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x9a: SBC A,D 1 4
                        subx a, d               wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x9b: SBC A,E 1 4
                        subx a, e               wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x9c: SBC A,H 1 4
                        subx a, h               wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x9d: SBC A,L 1 4
                        subx a, l               wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x9e: SBC A,(HL) 1 8
                        jmp #read_hl_exec_3
                        subx a, work            wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop

' 0x9f: SBC A,A 1 4
                        subx a, a               wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xa0: AND B 1 4
                        and a, b                wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xa1: AND C 1 4
                        and a, c                wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xa2: AND D 1 4
                        and a, d                wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xa3: AND E 1 4
                        and a, e                wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xa4: AND H 1 4
                        and a, h                wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xa5: AND L 1 4
                        and a, l                wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xa6: AND (HL) 1 8
                        jmp #read_hl_exec_3
                        and a, work             wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xa7: AND A 1 4
                        and a, a                wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xa8: XOR B 1 4
                        xor a, b                wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xa9: XOR C 1 4
                        xor a, c                wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xaa: XOR D 1 4
                        xor a, d                wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xab: XOR E 1 4
                        xor a, e                wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xac: XOR H 1 4
                        xor a, h                wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xad: XOR L 1 4
                        xor a, l                wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xae: XOR (HL) 1 8
                        jmp #read_hl_exec_3
                        xor a, work             wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xaf: XOR A 1 4
                        xor a, a                wz, wc
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xb0: OR B 1 4
                        or a, b                 wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xb1: OR C 1 4
                        or a, c                 wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xb2: OR D 1 4
                        or a, d                 wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xb3: OR E 1 4
                        or a, e                 wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xb4: OR H 1 4
                        or a, h                 wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xb5: OR L 1 4
                        or a, l                 wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xb6: OR (HL) 1 8
                        jmp #read_hl_exec_3
                        or a, work              wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xb7: OR A 1 4
                        or a, a                 wz
                        xor a, a                wc, nr
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xb8: CP B 1 4
                        cmp a, b                wz, wc
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xb9: CP C 1 4
                        cmp a, c                wz, wc
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xba: CP D 1 4
                        cmp a, d                wz, wc
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xbb: CP E 1 4
                        cmp a, e                wz, wc
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xbc: CP H 1 4
                        cmp a, h                wz, wc
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xbd: CP L 1 4
                        cmp a, l                wz, wc
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xbe: CP (HL) 1 8
                        jmp #read_hl_exec_3
                        cmp a, work             wz, wc
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xbf: CP A 1 4
                        cmp a, a                wz, wc
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xc0: RET NZ 1 20/8
                        mov work, #6
                        call #wait_work
                        jmp #exec_2
                        testn z_flag, f         wz
              if_nz     jmp #exec_1
                        jmp #do_ret
                        nop
                        nop

' 0xc1: POP BC 1 12
                        jmp #exec_3
                        call #read_sp_to_work_16
                        mov b, work_high
                        mov c, work_low
                        nop
                        nop
                        nop
                        nop

' 0xc2: JP NZ,a16 3 16/12
                        jmp #read_imm_16
                        jmp #exec_3
                        testn z_flag, f         wz
              if_z      jmp #finish_loop
                        jmp #jmp_work_16
                        nop
                        nop
                        nop

' 0xc3: JP a16 3 16
                        jmp #read_imm_16
                        nop
                        jmp #exec_2
                        nop
                        jmp #jmp_work_16
                        nop
                        nop
                        nop

' 0xc4: CALL NZ,a16 3 24/12
                        jmp #read_imm_16
                        jmp #exec_3
                        testn z_flag, f         wz
              if_z      jmp #finish_loop
                        jmp #call_work_16
                        nop
                        nop
                        nop

' 0xc5: PUSH BC 1 16
                        jmp #exec_7
                        mov work_16, b
                        shl work_16, #8
                        or work_16, c
                        sub sp, #2
                        call #write_work_16_to_sp
                        nop
                        nop

' 0xc6: ADD A,d8 2 8
                        jmp #read_imm_exec_3
                        add a, work
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop

' 0xc7: RST 00H 1 16
                        jmp #exec_3
                        mov work_16, #$00
                        nop
                        jmp #call_work_16
                        nop
                        nop
                        nop
                        nop

' 0xc8: RET Z 1 20/8
                        mov work, #6
                        call #wait_work
                        jmp #exec_2
                        testn z_flag, f         wz
              if_z      jmp #exec_1
                        jmp #do_ret
                        nop
                        nop

' 0xc9: RET 1 16
                        jmp #exec_3
                        nop
                        nop
                        jmp #do_ret
                        nop
                        nop
                        nop
                        nop

' 0xca: JP Z,a16 3 16/12
                        jmp #read_imm_16
                        jmp #exec_3
                        testn z_flag, f         wz
              if_nz     jmp #finish_loop
                        jmp #jmp_work_16
                        nop
                        nop
                        nop

' 0xcb: PREFIX CB 1 4
                        jmp #prefix_cb
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xcc: CALL Z,a16 3 24/12
                        jmp #read_imm_16
                        jmp #exec_3
                        testn z_flag, f         wz
              if_nz     jmp #finish_loop
                        jmp #call_work_16
                        nop
                        nop
                        nop

' 0xcd: CALL a16 3 24
                        jmp #read_imm_16
                        nop
                        jmp #exec_2
                        nop
                        jmp #call_work_16
                        nop
                        nop
                        nop

' 0xce: ADC A,d8 2 8
                        jmp #read_imm_exec_3
                        addx a, work
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop

' 0xcf: RST 08H 1 16
                        jmp #exec_3
                        mov work_16, #$08
                        nop
                        jmp #call_work_16
                        nop
                        nop
                        nop
                        nop

' 0xd0: RET NC 1 20/8
                        mov work, #8
                        call #wait_work
                        jmp #exec_3
              if_c      jmp #finish_loop
                        jmp #do_ret
                        nop
                        nop
                        nop

' 0xd1: POP DE 1 12
                        jmp #exec_3
                        call #read_sp_to_work_16
                        mov d, work_high
                        mov e, work_low
                        nop
                        nop
                        nop
                        nop

' 0xd2: JP NC,a16 3 16/12
                        jmp #read_imm_16
                        nop
                        jmp #exec_2
              if_c      jmp #finish_loop
                        jmp #jmp_work_16
                        nop
                        nop
                        nop

' 0xd3: UNUSED 1 4
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xd4: CALL NC,a16 3 24/12
                        jmp #read_imm_16
                        nop
                        jmp #exec_2
              if_c      jmp #finish_loop
                        jmp #call_work_16
                        nop
                        nop
                        nop

' 0xd5: PUSH DE 1 16
                        jmp #exec_7
                        mov work_16, d
                        shl work_16, #8
                        or work_16, e
                        sub sp, #2
                        call #write_work_16_to_sp
                        nop
                        nop

' 0xd6: SUB d8 2 8
                        jmp #read_imm_exec_3
                        sub a, work
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop

' 0xd7: RST 10H 1 16
                        jmp #exec_3
                        mov work_16, #$10
                        nop
                        jmp #call_work_16
                        nop
                        nop
                        nop
                        nop

' 0xd8: RET C 1 20/8
                        mov work, #8
                        call #wait_work
                        jmp #exec_3
              if_nc     jmp #finish_loop
                        jmp #do_ret
                        nop
                        nop
                        nop

' 0xd9: RETI 1 16
                        jmp #exec_3
                        mov interrupt_flag, ints_enabled
                        nop
                        jmp #do_ret
                        nop
                        nop
                        nop
                        nop

' 0xda: JP C,a16 3 16/12
                        jmp #read_imm_16
                        nop
                        jmp #exec_2
              if_nc     jmp #finish_loop
                        jmp #jmp_work_16
                        nop
                        nop
                        nop

' 0xdb: UNUSED 1 4
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xdc: CALL C,a16 3 24/12
                        jmp #read_imm_16
                        nop
                        jmp #exec_2
              if_nc     jmp #finish_loop
                        jmp #call_work_16
                        nop
                        nop
                        nop

' 0xdd: UNUSED 1 4
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xde: SBC A,d8 2 8
                        jmp #read_imm_exec_3
                        subx a, work
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop

' 0xdf: RST 18H 1 16
                        jmp #exec_3
                        mov work_16, #$18
                        nop
                        jmp #call_work_16
                        nop
                        nop
                        nop
                        nop

' 0xe0: LDH (a8),A 2 12
                        jmp #read_imm_exec_3
                        jmp #exec_3
                        mov tmp, a
                        nop
                        jmp #write_tmp_to_work_io
                        nop
                        nop
                        nop

' 0xe1: POP HL 1 12
                        jmp #exec_3
                        call #read_sp_to_work_16
                        mov h, work_high
                        mov l, work_low
                        nop
                        nop
                        nop
                        nop

' 0xe2: LD (C),A 2 8
                        jmp #exec_3
                        mov tmp, a
                        mov work, c
                        jmp #write_tmp_to_work_io
                        nop
                        nop
                        nop
                        nop

' 0xe3: UNUSED 1 4
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xe4: UNUSED 1 4
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xe5: PUSH HL 1 16
                        jmp #exec_7
                        mov work_16, h
                        shl work_16, #8
                        or work_16, l
                        sub sp, #2
                        call #write_work_16_to_sp
                        nop
                        nop

' 0xe6: AND d8 2 8
                        jmp #read_imm_exec_3
                        and a, work
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop

' 0xe7: RST 20H 1 16
                        jmp #exec_3
                        mov work_16, #$20
                        nop
                        jmp #call_work_16
                        nop
                        nop
                        nop
                        nop

' 0xe8: ADD SP,r8 2 16
                        jmp #read_imm_exec_3
                        call #sum_sp_r8
                        jmp #exec_3
                        mov sp, work_16
                        mov work, #12
                        call #wait_work
                        nop
                        nop

' 0xe9: JP (HL) 1 4
                        jmp #jmp_hl
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xea: LD (a16),A 3 16
                        jmp #read_imm_16
                        nop
                        mov work, a
                        jmp #write_work_16
                        nop
                        nop
                        nop
                        nop

' 0xeb: UNUSED 1 4
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xec: UNUSED 1 4
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xed: UNUSED 1 4
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xee: XOR d8 2 8
                        jmp #read_imm_exec_3
                        xor a, work
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop

' 0xef: RST 28H 1 16
                        jmp #exec_3
                        mov work_16, #$28
                        nop
                        jmp #call_work_16
                        nop
                        nop
                        nop
                        nop

' 0xf0: LDH A,(a8) 2 12
                        jmp #read_imm_exec_3
                        jmp #read_work_io
                        jmp #exec_2
                        mov a, work
                        nop
                        nop
                        nop
                        nop

' 0xf1: POP AF 1 12
                        call #pop_af
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xf2: LD A,(C) 2 8
                        mov work, c
                        jmp #read_work_io
                        jmp #exec_1
                        mov a, work
                        nop
                        nop
                        nop
                        nop

' 0xf3: DI 1 4
                        mov interrupt_flag, ints_disabled
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xf4: UNUSED 1 4
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xf5: PUSH AF 1 16
                        jmp #exec_7
                        mov work_16, a
                        shl work_16, #8
                        or work_16, f
                        sub sp, #2
                        call #write_work_16_to_sp
                        nop
                        nop

' 0xf6: OR d8 2 8
                        jmp #read_imm_exec_3
                        or a, work
                        test a, #$100           wc
                        and a, #$FF             wz
                        nop
                        nop
                        nop
                        nop

' 0xf7: RST 30H 1 16
                        jmp #exec_3
                        mov work_16, #$30
                        nop
                        jmp #call_work_16
                        nop
                        nop
                        nop
                        nop

' 0xf8: LD HL,SP+r8 2 12
                        jmp #read_imm_exec_3
                        call #sum_sp_r8
                        jmp #exec_2
                        mov work, work_16
                        jmp #load_hl
                        nop
                        nop
                        nop

' 0xf9: LD SP,HL 1 8
                        mov sp, h
                        shl sp, #8
                        jmp #exec_3
                        add sp, l
                        mov work, #4
                        call #wait_work
                        nop
                        nop

' 0xfa: LD A,(a16) 3 16
                        jmp #read_imm_16
                        nop
                        nop
                        jmp #read_work_16
                        mov a, work
                        nop
                        nop
                        nop

' 0xfb: EI 1 4
                        mov interrupt_flag, ints_enabled
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xfc: UNUSED 1 4
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xfd: UNUSED 1 4
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xfe: CP d8 2 8
                        jmp #read_imm_exec_3
                        cmp a, work             wc, wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' 0xff: RST 38H 1 16
                        jmp #exec_3
                        mov work_16, #$38
                        nop
                        jmp #call_work_16
                        nop
                        nop
                        nop
                        nop

DAT
' PREFIX CB
' CB RLC
                        test work, #$80         wc
                        rcl work, #1
                        and work, #$FF          wz
                        nop
                        nop
                        nop
                        nop
                        nop

' CB RRC
                        shr work, #1            wc
                        muxc work, #$80         wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB RL
                        rcl work, #1
                        test work, #$100        wc
                        and work, #$FF          wz
                        nop
                        nop
                        nop
                        nop
                        nop

' CB RR
                        muxc work, #$100
                        shr work, #1            wc, wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB SLA
                        shl work, #1
                        test work, #$100        wc
                        and work, #$FF          wz
                        nop
                        nop
                        nop
                        nop
                        nop

' CB SRA
                        shl work, #24
                        sar work, #25           wc
                        and work, #$FF          wz
                        nop
                        nop
                        nop
                        nop
                        nop

' CB SWAP
                        mov tmp, work
                        shr work, #4
                        shl tmp, #4             wc
                        or work, tmp
                        and work, #$FF          wz
                        nop
                        nop
                        nop

' CB SRL
                        shr work, #1            wc, wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB BIT 0
                        test work, #$01         wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB BIT 1
                        test work, #$02         wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB BIT 2
                        test work, #$04         wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB BIT 3
                        test work, #$08         wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB BIT 4
                        test work, #$10         wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB BIT 5
                        test work, #$20         wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB BIT 6
                        test work, #$40         wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB BIT 7
                        test work, #$80         wz
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB RES 0
                        andn work, #$01
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB RES 1
                        andn work, #$02
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB RES 2
                        andn work, #$04
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB RES 3
                        andn work, #$08
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB RES 4
                        andn work, #$10
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB RES 5
                        andn work, #$20
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB RES 6
                        andn work, #$40
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB RES 7
                        andn work, #$80
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB SET 0
                        or work, #$01
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB SET 1
                        or work, #$02
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB SET 2
                        or work, #$04
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB SET 3
                        or work, #$08
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB SET 4
                        or work, #$10
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB SET 5
                        or work, #$20
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB SET 6
                        or work, #$40
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

' CB SET 7
                        or work, #$80
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop
                        nop

DAT
' PREFIX CB loading
                        mov work, b
                        mov b, work

                        mov work, c
                        mov c, work

                        mov work, d
                        mov d, work

                        mov work, e
                        mov e, work

                        mov work, h
                        mov h, work

                        mov work, l
                        mov l, work

                        jmp #read_hl_pcb
                        jmp #write_hl_finish

                        mov work, a
                        mov a, work

