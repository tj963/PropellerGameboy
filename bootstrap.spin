CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 6_000_000

OBJ
  cpu           : "cpu"
  'driver        : "driver"
  lcd           : "lcd2"
  sprite        : "sprite"
  video         : "video"
  lcd_driver    : "lcd_driver"
  timer         : "timer"
  sound         : "sound"

PUB Main
  byte[$7FFF][0] := $FF

  'cpu.Main
  video.Main
  lcd.Main
  sprite.Main
  lcd_driver.Main
  timer.Main
  sound.Main
  cpu.Main
