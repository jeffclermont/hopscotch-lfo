-- draw stuff on the screen
glyphs = include 'lib/glyphs'
local interface = {}
local screen_y = 29
local screen_x_mult = 14

function interface.draw_clock_div()
  if selected == #voices + 1 then
    screen.level(10)
  else
    screen.level(2)
  end
  screen.move(1, 64)
  
  -- Get base clock division
  local base_div = clock_div_options[params:get('hs_clock_division')]
  
  -- If LFO is enabled, show modulated value
  if params:get('hs_lfo_enable') == 1 then
    local lfo_mult = calculate_lfo()
    local modulated_div = string.format("%.2f", 1/(lfo_mult * (1/clock_div_values[params:get('hs_clock_division')])))
    screen.text(base_div .. " (" .. modulated_div .. ")")
  else
    screen.text(base_div)
  end
end

function interface.draw_gate()
  -- gate length
  if params:get('hs_output') == 2 then
    if selected == #voices + 2 then
      screen.level(10)
    else
      screen.level(1)
    end
    
    screen.move(114, 64)
    screen.text('int')
  else
    screen.level(1)
    screen.move(109, 62)
    screen.line_width(3)
    screen.line_rel(19, 0)
    screen.close()
    screen.stroke()
    if selected == #voices + 2 then
      screen.level(10)
    else
      screen.level(3)
    end
    screen.move(109, 62)
    screen.line_rel(19 * gate_values[params:get('hs_gate_length')], 0)
    screen.close()
    screen.stroke()
  end
end

function interface.draw_hold()
  screen.line_width(1)
  if params:get('hs_hold') == 1 then
    screen.level(1)
    screen.rect(108, 3, 20, 7)
    screen.fill()
    screen.level(15)
    screen.rect(107, 2, 20, 7)
    screen.fill()
    screen.move(108, 8)
    screen.level(0)
    screen.text('HOLD')
  else
    screen.level(1)
    screen.rect(108, 3, 20, 7)
    screen.fill()
    screen.move(109, 9)
    screen.level(0)
    screen.text('HOLD')
  end
  screen.stroke()
end

function interface.draw_lfo()
  -- LFO parameters display
  if selected == #voices + 3 then
    screen.level(10)
  else
    screen.level(2)
  end
  screen.move(1, 18)
  screen.text('LFO ' .. string.format("%.2f", params:get('hs_lfo_rate')) .. 'Hz')
  
  if selected == #voices + 4 then
    screen.level(10)
  else
    screen.level(2)
  end
  screen.move(50, 18)
  screen.text('D:' .. string.format("%.2f", params:get('hs_lfo_depth')))
  
  if selected == #voices + 5 then
    screen.level(10)
  else
    screen.level(2)
  end
  screen.move(90, 18)
  local shapes = {'sin', 'tri', 'sqr', 'rnd'}
  screen.text(shapes[params:get('hs_lfo_shape')])
  
  -- LFO status indicator
  if params:get('hs_lfo_enable') == 1 then
    screen.level(15)
    screen.rect(107, 12, 20, 7)
    screen.fill()
    screen.level(0)
    screen.move(109, 18)
    screen.text('LFO')
  end
end

function interface.draw_sequences()
  for i=1, #voices do
    if selected == i then
      screen.level(15)
    else
      screen.level(2)
    end
    local sequence_index = params:get("hs_v"..i.."_sequence")
    sequences[sequence_index].glyph((screen_x_mult * i) - 3, screen_y + 12)
  end
end

function interface.draw_channels()
  for i=1, #voices do
    if selected == i then
      screen.level(15)
    else
      screen.level(2)
    end
    screen.move((screen_x_mult * i) - 2, screen_y + 12)
    screen.text(params:get("hs_v"..i.."_channel"))
  end
end

function interface.draw_activity()
  screen.level(15)
  for i=1, #voices do
    if voice_status[i] == 0 then
      glyphs.off((screen_x_mult * i) - 3, screen_y)
    elseif voice_status[i] == 1 then
      glyphs.on((screen_x_mult * i) - 3, screen_y)
    end
  end
end

return interface
