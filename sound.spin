CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 6_000_000

PUB Main
  cognew(@sound, 0)

DAT
                        org 0
sound                   rdbyte tmp, enable_addr         wz
              if_nz     jmp #sound

                        mov nr10, nr10_addr
                        mov tmp, #$14
setup_loop              wrbyte test_value, nr10
                        add nr10, #1
                        djnz tmp, #setup_loop

                        mov dira, sound_mask
                        mov frqa, #0
                        mov ctra, #0
                        movs ctra, sound_pin
                        movi ctra, sound_mode

                        mov c2_output, #0
                        mov frame_prev_cnt, cnt

loop                    rdbyte nr52, nr52_addr
                        andn nr52_prev, nr52
                        andn nr52_set, nr52_prev
                        or nr52, nr52_set
                        andn nr52, nr52_clear

                        rdlong write_cnt, write_cnt_addr
                        mov check_cnt, cnt
                        sub check_cnt, write_cnt
                        cmp check_cnt, #64      wc
              if_c      jmp #loop
                        wrbyte nr52, nr52_addr
                        mov nr52_set, #0
                        mov nr52_clear, #0
                        mov nr52_prev, nr52


channel1                nop
read_nr11               rdbyte tmp, nr11_addr
                        cmp tmp, test_value     wz
              if_z      jmp #read_nr13
                        wrbyte test_value, nr21_addr
                        mov nr11, tmp
                        and tmp, #$3F
                        neg c1_length, tmp
                        add c1_length, #64

read_nr13               rdbyte tmp, nr13_addr
                        cmp tmp, test_value     wz
              if_z      jmp #read_nr14
                        wrbyte test_value, nr13_addr
                        mov nr13, tmp

read_nr14               rdbyte tmp, nr14_addr
                        cmp tmp, test_value     wz
              if_z      jmp #check_c1_init
                        wrbyte test_value, nr14_addr
                        mov nr14, tmp

check_c1_init           test nr14, #$80         wc
              if_nc     jmp #update_c1
                        andn nr14, #$80
                        or nr52_set, #$01
                        rdbyte nr12, nr12_addr
                        mov c1_volume, nr12
                        shr c1_volume, #4       wz
              if_z      test nr12, #$08         wz
              if_z      andn nr12, #$07
                        mov c2_period, nr12
                        and c2_period, #$07


update_c1               mov tmp, nr14
                        and tmp, #$07
                        shl tmp, #8
                        or tmp, nr13
                        cmp tmp, c1_freq        wz
              if_z_and_nc jmp #update_c1_duty

                        mov c1_freq, tmp
                        mov c1_freq_cnt, c1_freq
                        neg c1_freq_cnt, c1_freq_cnt
                        add c1_freq_cnt, freq_sub
                        min c1_freq_cnt, #8
                        mov tmp, c1_freq_cnt
                        shl c1_freq_cnt, #1
                        add c1_freq_cnt, tmp
                        shl c1_freq_cnt, #5

update_c1_duty          mov tmp, nr11
                        shr tmp, #6
                        cmp tmp, c1_duty        wz
              if_z_and_nc jmp #do_c1
                        mov c1_duty, tmp
                        add tmp, #duty0
                        movs load_c1_duty, tmp
                        nop
load_c1_duty            mov c1_duty_shift, duty0

do_c1                   mov saved_cnt, cnt
              if_c      jmp #do_c1_freq
                        mov tmp, saved_cnt
                        sub tmp, c1_prev_cnt
                        cmp tmp, c1_freq_cnt    wc
              if_b      jmp #done_c1_freq
do_c1_freq              mov c1_prev_cnt, saved_cnt
                        rol c1_duty_shift, #1   wc
                        muxc c1_output, c1_volume
done_c1_freq            nop


channel2                nop
read_nr21               rdbyte tmp, nr21_addr
                        cmp tmp, test_value     wz
              if_z      jmp #read_nr23
                        wrbyte test_value, nr21_addr
                        mov nr21, tmp
                        and tmp, #$3F
                        neg c2_length, tmp
                        add c2_length, #64

read_nr23               rdbyte tmp, nr23_addr
                        cmp tmp, test_value     wz
              if_z      jmp #read_nr24
                        wrbyte test_value, nr23_addr
                        mov nr23, tmp

read_nr24               rdbyte tmp, nr24_addr
                        cmp tmp, test_value     wz
              if_z      jmp #check_c2_init
                        wrbyte test_value, nr24_addr
                        mov nr24, tmp

check_c2_init           test nr24, #$80         wc
              if_nc     jmp #update_c2
                        andn nr24, #$80
                        or nr52_set, #$02
                        rdbyte nr22, nr22_addr
                        mov c2_volume, nr22
                        shr c2_volume, #4       wz
              if_z      test nr22, #$08         wz
              if_z      andn nr22, #$07
                        mov c2_period, nr22
                        and c2_period, #$07


update_c2               mov tmp, nr24
                        and tmp, #$07
                        shl tmp, #8
                        or tmp, nr23
                        cmp tmp, c2_freq        wz
              if_z_and_nc jmp #update_c2_duty

                        mov c2_freq, tmp
                        mov c2_freq_cnt, c2_freq
                        neg c2_freq_cnt, c2_freq_cnt
                        add c2_freq_cnt, freq_sub
                        min c2_freq_cnt, #8
                        mov tmp, c2_freq_cnt
                        shl c2_freq_cnt, #1
                        add c2_freq_cnt, tmp
                        shl c2_freq_cnt, #5

update_c2_duty          mov tmp, nr21
                        shr tmp, #6
                        cmp tmp, c2_duty        wz
              if_z_and_nc jmp #do_c2
                        mov c2_duty, tmp
                        add tmp, #duty0
                        movs load_c2_duty, tmp
                        nop
load_c2_duty            mov c2_duty_shift, duty0

do_c2                   mov saved_cnt, cnt
              if_c      jmp #do_c2_freq
                        mov tmp, saved_cnt
                        sub tmp, c2_prev_cnt
                        cmp tmp, c2_freq_cnt    wc
              if_b      jmp #done_c2_freq
do_c2_freq              mov c2_prev_cnt, saved_cnt
                        rol c2_duty_shift, #1   wc
                        muxc c2_output, c2_volume
done_c2_freq            nop


channel3                nop


check_frame             mov saved_cnt, cnt
                        mov tmp, saved_cnt
                        sub tmp, frame_prev_cnt
                        cmp tmp, frame_cnt      wc
              if_b      jmp #done_frame
do_frame                mov frame_prev_cnt, saved_cnt
                        add frame_step, #1
                        and frame_step, #$07


                        test frame_step, #$01   wz
              if_z      jmp #check_frame_volume

do_frame_length_c1      test nr14, #$40         wz
              if_nz     test nr52, #$01         wz
              if_z      jmp #do_frame_length_c2
                        sub c1_length, #1       wz
                        and c1_length, #$3F
              if_nz     or nr52_set, #$01
              if_z      or nr52_clear, #$01
do_frame_length_c2      test nr24, #$40         wz
              if_nz     test nr52, #$02         wz
              if_z      jmp #do_frame_length_c3
                        sub c2_length, #1       wz
                        and c2_length, #$3F
              if_nz     or nr52_set, #$02
              if_z      or nr52_clear, #$02
do_frame_length_c3      nop
                        jmp #done_frame


check_frame_volume      cmp frame_step, #6      wz
              if_nz     jmp #check_frame_sweep

do_frame_volume_c1      and nr12, #$07          wz
              if_nz     test nr52, #$01         wz
              if_z      jmp #do_frame_volume_c2
                        sub c1_period, #1       wz
              if_nz     jmp #do_frame_volume_c2
                        mov c1_period, nr12
                        and c1_period, #$07
                        test nr12, #$08         wz
              if_z      jmp #sub_frame_volume_c1
                        add c1_volume, #1
                        test c1_volume, #$0F    wz
              if_z      mov c1_volume, #$0F
              if_z      andn nr12, #$07
                        jmp #do_frame_volume_c2
sub_frame_volume_c1     sub c1_volume, #1       wz
              if_z      andn nr12, #$07

do_frame_volume_c2      and nr22, #$07          wz
              if_nz     test nr52, #$02         wz
              if_z      jmp #do_frame_volume_c3
                        sub c2_period, #1       wz
              if_nz     jmp #do_frame_volume_c3
                        mov c2_period, nr22
                        and c2_period, #$07
                        test nr22, #$08         wz
              if_z      jmp #sub_frame_volume_c2
                        add c2_volume, #1
                        test c2_volume, #$0F    wz
              if_z      mov c2_volume, #$0F
              if_z      andn nr22, #$07
                        jmp #do_frame_volume_c3
sub_frame_volume_c2     sub c2_volume, #1       wz
              if_z      andn nr22, #$07

do_frame_volume_c3      nop
                        jmp #done_frame

check_frame_sweep       nop
done_frame              nop

                        mov tmp, #0
                        test nr52, #$80         wz
              if_z      jmp #do_output

                        rdbyte nr51, nr51_addr
                        mov nr51, #$FF
                        mov tmp, nr51
                        shr tmp, #4
                        or tmp, nr51
                        and tmp, nr52

                        mov output, #0
                        test tmp, #$02          wz
              if_nz     add output, c2_output
                        test tmp, #$01          wz
              if_nz     add output, c1_output

                        rdbyte nr50, #$77
                        rdbyte nr50, nr50_addr
                        mov tmp, nr50
                        shr tmp, #4
                        and nr50, #$07
                        and tmp, #$07
                        add nr50, tmp
                        shr nr50, #1
                        add nr50, #1

                        mov tmp, #0
                        test nr50, #$08
              if_nz     add tmp, output         wz
                        shl tmp, #1
                        test nr50, #$04
              if_nz     add tmp, output         wz
                        shl tmp, #1
                        test nr50, #$02
              if_nz     add tmp, output         wz
                        shl tmp, #1
                        test nr50, #$01
              if_nz     add tmp, output         wz

                        shl tmp, #23
do_output               mov frqa, tmp
                        jmp #loop


tmp                     long 0
enable_addr             long $7FFF
test_value              long $7D

nr10                    long 0
nr10_addr               long $3F10
nr11                    long 0
nr11_addr               long $3F11
nr12                    long 0
nr12_addr               long $3F12
nr13                    long 0
nr13_addr               long $3F13
nr14                    long 0
nr14_addr               long $3F14

nr21                    long 0
nr21_addr               long $3F16
nr22                    long 0
nr22_addr               long $3F17
nr23                    long 0
nr23_addr               long $3F18
nr24                    long 0
nr24_addr               long $3F19

nr50                    long 0
nr50_addr               long $3F24
nr51                    long 0
nr51_addr               long $3F25
nr52                    long 0
nr52_set                long 0
nr52_clear              long 0
nr52_prev               long 0
nr52_addr               long $3F26

c1_length               long $FFFFFFFF
c1_freq                 long $FFFFFFFF
c1_freq_cnt             long 0
c1_prev_cnt             long $FFFFFFFF
c1_duty                 long $FFFFFFFF
c1_duty_shift           long 0
c1_period               long 0
c1_volume               long 0
c1_output               long 0

c2_length               long $FFFFFFFF
c2_freq                 long $FFFFFFFF
c2_freq_cnt             long 0
c2_prev_cnt             long $FFFFFFFF
c2_duty                 long $FFFFFFFF
c2_duty_shift           long 0
c2_period               long 0
c2_volume               long 0
c2_output               long 0

frame_step              long 0
frame_cnt               long 196608
frame_prev_cnt          long 0

duty0                   long $01010101
duty1                   long $81818181
duty2                   long $87878787
duty3                   long $7E7E7E7E

freq_sub                long 2048
saved_cnt               long 0
output                  long 0

check_cnt               long 0
write_cnt               long 0
write_cnt_addr          long $3DF0

sound_mask              long $08000000
sound_pin               long 27
sound_mode              long $30

mailbox_long            long $3DF4
mailbox_long1           long $3DF5
mailbox_long2           long $3DF6
mailbox_long3           long $3DF7

ctr0                    long 0
ctr1                    long 0
ctr2                    long 0
ctr3                    long 0

