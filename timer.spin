CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 6_000_000

PUB Main
  cognew(@timer, 0)

DAT
                        org 0
timer                   rdbyte tmp, enable_addr         wz
              if_nz     jmp #timer

                        mov tima_cnt, cnt
                        wrbyte write_default, tima_addr
                        wrbyte write_default, div_addr

main_loop               rdbyte tac, tac_addr
                        test tac, #$04          wz
              if_z      jmp #disable_tima

                        rdbyte tima, tima_addr
                        cmp tima, write_default wz
              if_nz     jmp #reset_tima

                        mov work, cnt
                        sub work, tima_cnt

                        test tac, #$01          wz
                        test tac, #$02          wc
              if_z_and_nc shr work, #13
              if_nz_and_nc shr work, #7
              if_z_and_c shr work, #9
              if_nz_and_c shr work, #11

                        mov tmp, work
                        shl tmp, #2
                        add work, tmp
                        shl tmp, #2
                        add work, tmp
                        shl tmp, #2
                        add work, tmp
                        shl tmp, #2
                        add work, tmp
                        shr work, #10

                        mov tima, tima_prev
                        add tima, work
                        cmp tima, #256          wc
              if_b      jmp #write_tima

                        lockset timer_lock
                        mov tima_cnt, cnt
                        rdbyte tima_prev, tma_addr
                        mov tima, tima_prev

write_tima              wrbyte tima, tima_addr_read
                        jmp #done_tima

reset_tima              wrbyte tima, tima_addr_read
                        mov tima_prev, tima
                        wrbyte write_default, tima_addr

disable_tima            mov tima_cnt, cnt

done_tima               nop


                        rdbyte div, div_addr
                        cmp div, write_default  wz
              if_nz     jmp #reset_div

                        mov work, cnt
                        sub work, div_cnt
                        shr work, #11

                        mov tmp, work
                        shl work, #1
                        shl tmp, #2
                        add work, tmp
                        shl tmp, #2
                        add work, tmp
                        shl tmp, #2
                        add work, tmp
                        shl tmp, #2
                        add work, tmp
                        shr work, #10

                        mov div, div_prev
                        add div, work
                        cmp div, #256           wc
              if_b      jmp #write_div

                        mov div_cnt, cnt
                        mov div_prev, #0
                        mov div, #0

write_div               wrbyte div, div_addr_read
                        jmp #done_div

reset_div               mov div_prev, #0
                        wrbyte div_prev, div_addr_read
                        mov tima_cnt, cnt
                        wrbyte write_default, div_addr

done_div                nop

                        jmp #main_loop


enable_addr             long $7FFF

work                    long 0
tmp                     long 0

write_default           long 83

tima                    long 0
tima_prev               long 0
tima_cnt                long 0
tima_addr               long $3F05
tima_addr_read          long $3D05
tma                     long 0
tma_addr                long $3F06
tac                     long 0
tac_addr                long $3F07

tima_shift_0            long 13
                        long 7
                        long 9
                        long 11

div                     long 0
div_prev                long 0
div_cnt                 long 0
div_addr                long $3F04
div_addr_read           long $3D04

timer_lock              long 5

