CON
  ' Set up the processor clock in the standard way for 80MHz
  _CLKMODE = xtal1 + pll16x
  _XINFREQ = 6_000_000

PUB Main
  cognew(@entry, 0)

DAT                     org
entry                   jmp #initialization             'Jump past the constants

' I want to explain some important constants up front, so I'll declare them here.
' Ordinarily they'd be tucked away after the code.  There is also a lot of skipping
' arounf between CON and DAT sections.  I'm declaring them in the order I can best explain them.
'
' I've used some naming conventions.  These prefixes mean:
' NTSC_ :   The value is a constant of the NTSC system. They would probably be the same no matter
'           what resolution or color mode you are using.  You'd probably only change them if you were
'           converting to PAL.  In which case, good luck to you.
' CHOOSE_ : A choice was made for this particular resolution and color depth.  You might change these.
' CALC_     These were calculated from one or more of the choices you made.  Choose again and you may
'           have to change these.

'***************************************************
'* Color Frequency                                 *
'***************************************************
'
' The NTSC output is a signal with various elements that need timing relative to each other.  So we need some
' sort of clock from which to time all the elements.  The frequency of the color carrier is useful.  This is
' 3.579545 Mhz. A cycle of this clock will take 1sec/3.579545MHz = 279.365ns.

CON  NTSC_color_frequency       =     3_579_545
DAT  NTSC_color_freq            long  NTSC_color_frequency

' Additionally this period of 279ns is divided up into 16 by a Phased Locked Loop circuit (PLL), and it is multiples
' this period that the Video Scale Hardware Register (VSCL) is programmed.  This period of 17.460313ns is called a
' "clock".



'***************************************************
'* Horizontal sync                                 *
'***************************************************
'* A hsync takes 10.9us.  That's 10.9us/17.460313ns = 624 clocks (rounded to an integer).
CON  NTSC_hsync_clocks          =               624

' We are going to send each horizontal sync with a single WAITVID.  We'll aproximate the waveform with
' 16 x 4 "color" pixels.  So we need to program the Video Scale register VSCL.  That looks like this:
'
' %xxxx_xxxx_xxxx_________________________ : Not used
' %_______________PPPP_PPPP_______________ : Clocks per pixel (CPP)
' %_________________________FFFF_FFFF_FFFF : Clocks per frame (CPF)
'
' The number of pixels we get is CPF/CPP.  So for this usage CPS is 624/16 = 39.
DAT  NTSC_hsync_VSCL            long  NTSC_hsync_clocks >> 4 << 12 + NTSC_hsync_clocks

' The hsync is made up of 3 different sorts of signal.  We put them into a palette:
' Color0 = Color NTSC_control_signal_palette (yellow hue at zero value) = $8a
' Color1 = Black = $02
' Color2 = Blanking level = $00
' Color4 = don't care
' Note that the palette is programmed in reverse order:
DAT  NTSC_control_signal_palette long  $00_00_02_8a

' Then we construct a hsync out of 16 pixels of those control signals.
' Note that this is shifted out of the VSU to the right, so LSB goes first.
DAT  NTSC_hsync_pixels          long  %%11_0000_1_2222222_11



'***************************************************
'* Blank lines                                     *
'***************************************************
' The rest of the line after a hsync takes 52.6us.  That's 3008 clocks (to the nearest multiple of 16).
CON  NTSC_active_video_clocks   =     3008

' For blank lines, were' going to programme the VSCL so it slowly outputs 16 pixels over the entire
' length of the active line.  It's all going to be one colour so we don't even need to programme the
' clocks per pixel part, just the clocks per frame.
DAT  NTSC_active_video_VSCL     long  NTSC_active_video_clocks



'***************************************************
'* User graphics lines                             *
'***************************************************
' The important lines at last.  To fit 256 pixels in, we're going to make them 10 clocks each.
' That's 2560 clocks for the user graphics width.  You could use 11 clocks each or some other near value.
' It depends whether you want overscan to the left and right.
CON CHOOSE_clocks_per_gfx_pixel = 10

' Because we're going to use 256 color mode, we're only going to output 4 pixels per WAITVID.  So that
' decides the number of clocks per frame.  4.
CON CALC_clocks_per_gfx_frame   =     CHOOSE_clocks_per_gfx_pixel*16

' Program the VSCL as before.
DAT CALC_user_data_VSCL         long  CHOOSE_clocks_per_gfx_pixel << 12 + CALC_clocks_per_gfx_frame

' So if we're doing 256 pixels, 4 at a time, that's 256/4 = 64 frames.  16 WAITVIDS.
CON CALC_frames_per_gfx_line    = 160/16

' There is some extra active video that is not used for user graphics.  This is the overscan.
CON CALC_overscan = NTSC_active_video_clocks-CALC_frames_per_gfx_line*CALC_clocks_per_gfx_frame

' It maybe that your TV doesn't centre the picture.  We can tweak the overscan left and right to make
' it balance.  28 works quite well on my TV.  It may well be different for yours.
CON CHOOSE_horizontal_offset    = 28

' So we can work out how much overscan to do left (backporch) and right (frontporch).
CON CALC_backporch = CALC_overscan/2+28
CON CALC_frontporch = CALC_overscan - CALC_overscan/2-28

DAT

'***************************************************
'* The code                                        *
'***************************************************
' Start of real code

initialization          mov i2c_data_2, #0

                        mov i2c_addr, #$52
                        mov i2c_data_1, #$40
                        shl i2c_data_1, #24
                        mov i2c_bitcount, #56
                        mov i2c_state, #i2c_write
                        call #i2csend
                        mov wait, cnt
                        add wait, i2cpause
                        waitcnt wait, #0

                        mov i2c_addr, #$52
                        mov i2c_data_1, #$46
                        shl i2c_data_1, #24
                        mov i2c_bitcount, #56
                        mov i2c_state, #i2c_write
                        call #i2csend
                        mov wait, cnt
                        add wait, i2cpause
                        waitcnt wait, #0

                        mov i2c_addr, #$52
                        mov i2c_data_1, #$4C
                        shl i2c_data_1, #24
                        mov i2c_bitcount, #40
                        mov i2c_state, #i2c_write
                        call #i2csend
                        mov wait, cnt
                        add wait, i2cpause
                        waitcnt wait, #0

                        jmp #enable_wait

i2csend                 mov i2c_continue, #i2ccont
                        jmp i2c_state

i2cloop                 mov wait, cnt
                        add wait, i2cwait
                        waitcnt wait, #0

                        jmp i2c_state
i2ccont                 tjnz i2c_state, #i2cloop
i2csend_ret             ret

i2c_write               mov i2c_do_cmd, #i2c_write_1
                        shl i2c_addr, #25
                        mov i2c_bit, #8
                        mov i2c_shift, i2c_data_1
                        jmp #i2c_start_1

i2c_read                mov i2c_do_cmd, #i2c_read_1
                        shl i2c_addr, #1
                        or i2c_addr, #1
                        shl i2c_addr, #24
                        mov i2c_bit, #8
                        mov i2c_shift, #0
                        jmp #i2c_start_1

i2c_start_1             or dira, i2c_sda
                        mov i2c_state, #i2c_start_2
                        jmp i2c_continue

i2c_start_2             or dira, i2c_scl
                        mov i2c_state, #i2c_addr_1
                        jmp i2c_continue

i2c_addr_1              or dira, i2c_scl
                        shl i2c_addr, #1        wc
                        nop
                        nop
                        nop
                        muxnc dira, i2c_sda
                        mov i2c_state, #i2c_addr_2
                        jmp i2c_continue

i2c_addr_2              andn dira, i2c_scl
                        sub i2c_bit, #1    wz
              if_nz     mov i2c_state, #i2c_addr_1
              if_z      mov i2c_state, #i2c_recv_ack_send_nack
                        jmp i2c_continue

i2c_recv_ack_send_nack  or dira, i2c_scl
                        nop
                        nop
                        nop
                        nop
                        andn dira, i2c_sda
                        mov i2c_state, #i2c_finish_ack
                        jmp i2c_continue


i2c_send_ack            or dira, i2c_scl
                        or dira, i2c_sda
                        mov i2c_state, #i2c_finish_ack
                        jmp i2c_continue

i2c_finish_ack          andn dira, i2c_scl
                        mov i2c_state, i2c_do_cmd
                        jmp i2c_continue

i2c_write_1             or dira, i2c_scl
                        shl i2c_shift, #1       wc
                        nop
                        nop
                        nop
                        muxnc dira, i2c_sda
                        mov i2c_state, #i2c_write_2
                        jmp i2c_continue

i2c_write_2             andn dira, i2c_scl
                        add i2c_bit, #1
                        cmp i2c_bitcount, i2c_bit       wz
              if_z      jmp #i2c_write_2_done
                        test i2c_bit, #31               wz
              if_z      mov i2c_shift, i2c_data_2
                        test i2c_bit, #7                wz
              if_z      mov i2c_state, #i2c_recv_ack_send_nack
              if_nz     mov i2c_state, #i2c_write_1
                        jmp i2c_continue
i2c_write_2_done        mov i2c_do_cmd, #i2c_stop_1
                        mov i2c_state, #i2c_recv_ack_send_nack
                        jmp i2c_continue

i2c_read_1              or dira, i2c_scl
                        andn dira, i2c_sda
                        mov i2c_state, #i2c_read_2
                        jmp i2c_continue

i2c_read_2              andn dira, i2c_scl
                        shl i2c_shift, #1
                        test i2c_sda, ina       wz
                        muxnz i2c_shift, #1
                        add i2c_bit, #1
                        cmp i2c_bitcount, i2c_bit       wz
              if_z      jmp #i2c_read_2_done
                        test i2c_bit, #31               wz
              if_z      mov i2c_data_2, i2c_shift
                        test i2c_bit, #7                wz
              if_z      mov i2c_state, #i2c_send_ack
              if_nz     mov i2c_state, #i2c_read_1
                        jmp i2c_continue
i2c_read_2_done         mov i2c_do_cmd, #i2c_stop_1
                        mov i2c_state, #i2c_recv_ack_send_nack
                        mov i2c_data_1, i2c_data_2
                        mov i2c_data_2, i2c_shift
                        jmp i2c_continue

i2c_stop_1              or dira, i2c_scl
                        nop
                        nop
                        nop
                        nop
                        or dira, i2c_sda
                        mov i2c_state, #i2c_stop_2
                        jmp i2c_continue

i2c_stop_2              andn dira, i2c_scl
                        mov i2c_state, #i2c_stop_3
                        jmp i2c_continue

i2c_stop_3              andn dira, i2c_sda
                        mov i2c_state, #0
                        jmp i2c_continue


i2c_state               long 0
i2c_continue            long 0
i2c_shift               long 0
i2c_data_1              long 0
i2c_data_2              long 0
i2c_bitcount            long 0
i2c_addr                long 0
i2c_bit                 long 0
i2c_do_cmd              long 0

i2c_sda                 long $20000000
i2c_scl                 long $10000000
wait                    long 0
i2cwait                 long 500
i2cpause                long 50000

joy_data                long 0
joy_init                long %1110_1111_1101_1111
joy_addr                long $3DEC
left_bit                long $0002
up_bit                  long $0001
right_bit               long $8000
down_bit                long $4000
a_bit                   long $0010
b_bit                   long $0040
start_bit               long $0400
select_bit              long $1000

left_mask               long %1111_1101_1111_1111
up_mask                 long %1111_1011_1111_1111
right_mask              long %1111_1110_1111_1111
down_mask               long %1111_0111_1111_1111

a_mask                  long %1111_1111_1111_1110
b_mask                  long %1111_1111_1111_1101
start_mask              long %1111_1111_1111_0111
select_mask             long %1111_1111_1111_1011

enable_wait             rdbyte pixel, enable_addr       wz
              if_nz     jmp #enable_wait

                        ' VCFG: setup Video Configuration register and 3-bit tv DAC pins to output
                        movs    VCFG, #%0000_0111       ' VCFG'S = pinmask (pin31: 0000_0111 : pin24)
                        movd    VCFG, #3                ' VCFG'D = pingroup (grp. 3 i.e. pins 24-31)

                        movi    VCFG, #%0_10_111_000    ' baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
                                                        ' %0_xx_x_x_x_xxx : Not used
                                                        ' %x_10_x_x_x_xxx : Composite video to top nibble, broadcast to bottom nibble
                                                        ' %x_xx_1_x_x_xxx : 4 color mode
                                                        ' %x_xx_x_1_x_xxx : Enable chroma on broadcast
                                                        ' %x_xx_x_x_1_xxx : Enable chroma on baseband
                                                        ' %x_xx_x_x_x_000 : Broadcast Aural FM bits (don't care)

                        or      DIRA, tvport_mask       ' set DAC pins to output

                        ' CTRA: setup Frequency to Drive Video
                        movi    CTRA,#%00001_111        ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                        mov     r1, NTSC_color_freq     ' r1: Color frequency in Hz (3.579_545MHz)
                        mov     r2, v_clkfreq           ' r2: CLKFREQ (96MHz)
                        call    #dividefract            ' perform r3 = 2^32 * r1 / r2
                        mov     v_freq, r3              ' v_freq now contains frqa.       (191)
                        mov     FRQA, r3                ' set frequency for counter

'-----------------------------------------------------------------------------
                        'NTSC has 244 "visible" lines, but some of that is overscan etc.
                        '  so pick a number of lines for user graphics e.g. 192
                        '  then display (244-192)/2 = 26 lines of overscan before
                        '  and after the user display.
frame_loop              mov     ptr, framebuffer
                        mov     line_loop, #50          '(50 so far)

                        rdlong prev_data, mailbox_long
                        '''
                        {add frame, #1
                        and frame, #$1F          wz
              if_z      mov prev_data, ina}
                        '''

                        'There's always a horizontal sync at the start of each line.  The clever stuff is
                        '  in the constants described earlier.
:vert_back_porch        mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_control_signal_palette, hsync

                        'This is just a blank line.  I've made it brown just to show it's there
                        '  but you'd probably want it black.  Notice how the whole line (apart from the
                        '  hsyc is output with one WAITVID.
                        mov     VSCL, NTSC_active_video_VSCL
                        waitvid user_palette3, #0
                        djnz    line_loop, #:vert_back_porch
'-----------------------------------------------------------------------------
                        mov i2c_addr, #$52
                        mov i2c_data_1, #0
                        mov i2c_data_2, #0
                        mov i2c_bitcount, #48
                        mov i2c_state, #i2c_read
                        mov i2c_continue, #read_cont

                        'Time to do the user graphics lines.  We're having 192 of them.
                        mov     line_loop, #144         '(194 so far)
                        'hsync
user_graphics_lines     mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_control_signal_palette, hsync
                        'The overscan before the user graphics.  Green in this case.
                        mov     VSCL, backporch
                        waitvid user_palette3, #0

                        tjnz i2c_state, i2c_state
                        'And now at long last, the user graphics.  Program the VSCL for
                        '  4 pixels per frame.
read_cont               mov     VSCL, CALC_user_data_VSCL

                        'Output for color bar lines.  Let's make it really dumb and obvious where
                        '  all the work is done by showing all 64 frames for a single line.
                        '  The thing to reall take notice of here is how we do 256 color mode.
                        '  We've programmed for 4 pixels per WAITVID, and do we always make those
                        '  colors 3,2,1 and 0.  Then whatever we put in the palette (the first
                        '  parameter of WAITVID is what we get.  The numbers are backwards to
                        '  cancel out the backwardness of VSU serialisation.  It means that
                        '  you write pixels in the palette in the same order you want them on
                        '  screen.
                        mov pixel_count, #10

pixel_loop              rdlong pixel, ptr
                        add ptr, #4
                        waitvid colorbar0, pixel
                        djnz pixel_count, #pixel_loop

                        'We've finished drawing a user graphics line, whether it was color
                        '  bar or flag.  Now do the overscan bit.  This time in blue.
end_of_flag_line        mov    VSCL, frontporch
                        waitvid user_palette3, border
                        'loop
                        djnz    line_loop, #user_graphics_lines
'-----------------------------------------------------------------------------
                        'status lines
                        mov     line_loop, #32
                        mov offset, #0
                        'hsync
user_graphics_lines_t   mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_control_signal_palette, hsync
                        mov     VSCL, backporch
                        waitvid user_palette3, #0

                        mov     VSCL, CALC_user_data_VSCL
                        mov pixel, prev_data
                        mov pixel_count, #8

digit_loop_t            rol pixel, #4
                        mov tmp, pixel
                        and tmp, #$0F
                        cmp tmp, #10            wc
              if_b      add tmp, #48
              if_ae     add tmp, #55
                        shr tmp, #1             wc
                        shl tmp, #7
                        add tmp, digit_data
                        add tmp, offset
                        rdlong tmp, tmp

              if_nc     waitvid text_color0, tmp
              if_c      waitvid text_color1, tmp
                        djnz pixel_count, #digit_loop_t


                        mov pixel_count, #2
pixel_loop_t            waitvid user_palette3, #0
                        djnz pixel_count, #pixel_loop_t

                        'We've finished drawing a user graphics line, whether it was color
                        '  bar or flag.  Now do the overscan bit.  This time in blue.
end_of_flag_line_t      mov    VSCL, frontporch
                        waitvid user_palette3, border
                        add offset, #4
                        'loop
                        djnz    line_loop, #user_graphics_lines_t
'-----------------------------------------------------------------------------
                        'Overscan at the bottom of screen.  Same as top of screen, but
                        '  this time in magenta.
                        mov     line_loop, #18          '(244)
                        'hsync
vert_front_porch        mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_control_signal_palette, hsync
                        mov     VSCL, NTSC_active_video_VSCL
                        waitvid user_palette3, #0
                        djnz    line_loop, #vert_front_porch

                        cmp     i2c_data_1, all1        wz
              if_z      jmp     #done_joy

                        mov     joy_data, joy_init
                        test    i2c_data_2, left_bit    wz
              if_z      and     joy_data, left_mask
                        test    i2c_data_2, up_bit      wz
              if_z      and     joy_data, up_mask
                        test    i2c_data_2, right_bit   wz
              if_z      and     joy_data, right_mask
                        test    i2c_data_2, down_bit    wz
              if_z      and     joy_data, down_mask
                        test    i2c_data_2, a_bit       wz
              if_z      and     joy_data, a_mask
                        test    i2c_data_2, b_bit       wz
              if_z      and     joy_data, b_mask
                        test    i2c_data_2, start_bit   wz
              if_z      and     joy_data, start_mask
                        test    i2c_data_2, select_bit  wz
              if_z      and     joy_data, select_mask
                        wrword  joy_data, joy_addr
done_joy                nop

'-----------------------------------------------------------------------------
                        'This is the vertical sync.  It consists of 3 sections of 6 lines each.
                        mov     line_loop, #6           '(250)
:vsync_higha            mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_control_signal_palette, vsync_high_1
                        mov     VSCL, NTSC_active_video_VSCL
                        waitvid NTSC_control_signal_palette, vsync_high_2
                        djnz    line_loop, #:vsync_higha
'-----------------------------------------------------------------------------
                        mov     line_loop, #6           '(256)
:vsync_low              mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_control_signal_palette, vsync_low_1
                        mov     VSCL, NTSC_active_video_VSCL
                        waitvid NTSC_control_signal_palette, vsync_low_2
                        djnz    line_loop, #:vsync_low
'-----------------------------------------------------------------------------
                        mov     line_loop, #6           '(250)
:vsync_highb            mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_control_signal_palette, vsync_high_1
                        mov     VSCL, NTSC_active_video_VSCL
                        waitvid NTSC_control_signal_palette, vsync_high_2
                        djnz    line_loop, #:vsync_highb
'-----------------------------------------------------------------------------

                        jmp     #frame_loop

' General Purpose Registers
r0                      long                    $0                              ' should typically equal 0
r1                      long                    $0
r2                      long                    $0
r3                      long                    $0

pixel_count             long                    $0
pixel                   long                    $0
ptr                     long                    $0
framebuffer             long                    $2440

' Video (TV) Registers
tvport_mask             long                    %0000_0111<<24

v_freq                  long                    0

' Graphics related vars.
v_coffset               long                    $02020202                       ' color offset (every color is added by $02)
v_clkfreq               long                    $05B8D800

' /////////////////////////////////////////////////////////////////////////////
' dividefract:
' Perform 2^32 * r1/r2, result stored in r3 (useful for TV calc)
' This is taken from the tv driver.
' NOTE: It divides a bottom heavy fraction e.g. 1/2 and gives the result as a 32-bit fraction.
' /////////////////////////////////////////////////////////////////////////////
dividefract
                        mov     r0,#32+1
:loop                   cmpsub  r1,r2           wc
                        rcl     r3,#1
                        shl     r1,#1
                        djnz    r0,#:loop

dividefract_ret         ret                             '+140


'Pixel streams
'  These are shifted out of the VSU to the right, so lowest bits are actioned first.
'
hsync                   long    %%11_0000_1_2222222_11  ' Used with NTSC_control_signal_palette so:
                                                        '      0 = blanking level
                                                        '      1 = Black
                                                        '      2 = Color NTSC_control_signal_palette (yellow at zero value)
vsync_high_1            long    %%11111111111_222_11
vsync_high_2            long    %%1111111111111111
vsync_low_1             long    %%22222222222222_11
vsync_low_2             long    %%1_222222222222222
all_black               long    %%1111111111111111
border                  long    %%0000000000000000

' Some unimportant irrelevant constants for generating demo user display etc.
line_loop               long    0
tile_loop               long    0
stripe1                 long    %%1111111100000000
stripe2                 long    %%0000000011111111
backporch               long    CALC_backporch
frontporch              long    CALC_frontporch

'Palettes
'  These are always 4 colors (or blanking level) stored in reverse order:
'                               Color3_Color2_Color1_Color0
'

user_palette3           long    $02_02_02_02
colorbar0               long    $03_04_05_06
text_color0             long    $06_02_06_02
text_color1             long    $06_06_02_02

enable_addr             long    $7FFF
mailbox_long            long    $3DF4
'mailbox_long            long    $3F24
all1                    long    $FFFFFFFF
tmp                     long    0
digit_data              long    $00008000
offset                  long    0
frame                   long    0
prev_data               long    0

                        fit 496

