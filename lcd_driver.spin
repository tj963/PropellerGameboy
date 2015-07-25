CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 6_000_000

PUB Main
  cognew(@lcd_driver, 0)

DAT
                        org 0
lcd_driver              rdbyte work, enable_addr        wz
              if_nz     jmp #lcd_driver

                        mov work, #255
                        wrbyte work, ly_control_addr

lcd_loop                mov ly, #0
                        wrbyte ly, ly_addr

enable_wait             rdbyte lcdc, lcdc_addr
                        test lcdc, #$80         wz
              if_z      wrbyte ly, stat_write_addr
              if_z      jmp #enable_wait

                        mov line_count, #144

line_loop               wrbyte ly, ly_control_addr
                        wrbyte ly, ly_addr

                        mov stat_flags, #2
                        mov stat_mode_flag, #$20
                        call #update_stat

                        mov wait, cnt
                        add wait, cycles_oam
                        waitcnt wait, cycles_vram

                        mov stat_flags, #3
                        mov stat_mode_flag, #$00
                        call #update_stat
                        waitcnt wait, cycles_hblank

                        mov stat_flags, #0
                        mov stat_mode_flag, #$08
                        call #update_stat
                        waitcnt wait, #0

                        add ly, #1
                        djnz line_count, #line_loop

                        lockset if_lock
                        mov work, #255
                        mov line_count, #10

                        mov stat_flags, #1
                        mov stat_mode_flag, #$30
                        call #update_stat

                        mov stat_mode_flag, #$00

vblank_loop             wrbyte work, ly_control_addr
                        wrbyte ly, ly_addr

                        mov wait, cnt
                        add wait, cycles_oam

                        call #update_stat
                        waitcnt wait, cycles_vram

                        call #update_stat
                        waitcnt wait, cycles_hblank

                        call #update_stat
                        waitcnt wait, #0

                        add ly, #1
                        djnz line_count, #vblank_loop

                        jmp #lcd_loop

update_stat             rdbyte lyc, lyc_addr
                        cmp ly, lyc             wz
                        muxz stat_flags, #$04
                        rdbyte stat, stat_read_addr
              if_z      test stat, #$40         wz
                        test stat, stat_mode_flag       wc
                        wrbyte stat_flags, stat_write_addr
              if_z_or_c lockset stat_lock
update_stat_ret         ret


enable_addr             long $7FFF

work                    long 0
ly_control_addr         long $3DE8

lcdc                    long 0
lcdc_addr               long $3F40
stat                    long 0
stat_flags              long 0
stat_mode_flag          long 0
stat_read_addr          long $3F41
stat_write_addr         long $3DC1
ly                      long 0
ly_addr                 long $3F44
lyc                     long 0
lyc_addr                long $3F45
line_count              long 0

wait                    long 0
cycles_oam              long 1826
cycles_vram             long 3942
cycles_hblank           long 4673
if_lock                 long 7
stat_lock               long 6

