-- Hopscotch
--
-- -------------------------------
--
-- E2: select parameter
-- E3: adjust parameter
-- K1: shift - midi channels
-- K3: hold on/off
--
-- -------------------------------
--
-- v1.2.0 by @joeygordon
-- LFO mod added

engine.name = 'PolyPerc'

music = require 'musicutil'
ui = require 'ui'

parameters = include 'lib/parameters'
utils = include 'lib/utils'
interface = include 'lib/interface'
voices = include 'lib/voices'
sequences = include 'lib/sequences'
note_utils = include 'lib/note_utils'
encoder_actions = include 'lib/encoder_actions'
key_actions = include 'lib/key_actions'
glyphs = include 'lib/glyphs'

midi_in = midi.connect(1)
midi_out = midi.connect(2)
pages = ui.Pages.new(1, 2)
selected = 1
shift = false
voice_status = { 0, 0, 0, 0, 0, 0, 0, 0 }
clock_div_options = {'1/32', '1/16', '1/12', '1/8', '1/6', '1/4', '1/3', '1/2', '1'}
clock_div_values = {32, 16, 12, 8, 6, 4, 3, 2, 1}
gate_options = {'10%', '25%', '33%', '50%', '66%', '75%', '90%', '100%'}
gate_values = {0.10, 0.25, 0.333, 0.5, 0.666, 0.75, 0.9, 1}

-- LFO settings
lfo = {
  rate = 0.1,        -- LFO rate in Hz
  depth = 0.5,       -- Depth of modulation (0-1)
  phase = 0,         -- Current phase of LFO
  shape = "sine",    -- LFO shape (sine, triangle, square)
  enabled = false    -- LFO on/off state
  random_value = 0,  -- 
  last_phase = 0     -- 
}

-- manage sequence state
function calculate_lfo()
  local shape = params:get("hs_lfo_shape")
  local value = 0
  
  -- Calculate based on phase (0-1)
  if shape == 1 then -- sine
    value = math.sin(lfo.phase * math.pi * 2)
  elseif shape == 2 then -- triangle
    if lfo.phase < 0.5 then
      value = lfo.phase * 4 - 1
    else
      value = 3 - lfo.phase * 4
    end
  elseif shape == 3 then -- square
    value = lfo.phase < 0.5 and 1 or -1
  else -- random
    -- Generate new random value when phase cycles
    if lfo.last_phase and lfo.phase < lfo.last_phase then
      lfo.random_value = math.random() * 2 - 1
    end
    value = lfo.random_value or 0
    lfo.last_phase = lfo.phase
  end
  
  -- Apply depth
  value = value * params:get("hs_lfo_depth")
  
  -- Center around 1 for clock multiplication
  return 1 + value
end

function play_sequence(seq, voice, vel)
  while true do
    for i=1, #seq do
      local should_redraw = false
      if seq[i] == 1 then
        local note_val = utils.percentageChance(20) and 
          (voices[voice]["note"] + utils.randomOctave()) or 
          voices[voice]["note"]

        note_utils.play_note(
          note_val, 
          vel, 
          params:get('hs_v'..voice..'_channel'),
          voice
        )

        if voice_status[voice] ~= 1 then
          voice_status[voice] = 1
          should_redraw = true
        end
      else
        if voice_status[voice] ~= 0 then
          voice_status[voice] = 0
          should_redraw = true
        end
      end
      
      if should_redraw then
        redraw()
      end
      
      -- Calculate base clock time
      local clock_time = clock.get_beat_sec() / clock_div_values[params:get('hs_clock_division')]
      
      -- Apply LFO if enabled
      if params:get("hs_lfo_enable") == 1 then
        clock_time = clock_time * calculate_lfo()
      end
      
      if params:get('hs_grid_lock') == 1 then
        clock.sync(clock_time)
      else 
        clock.sleep(clock_time)
      end
    end
  end
end

function hold_release()
  for k, v in pairs(voices) do
    if v["hold_release"] == true then
      note_utils.release_note(k)
    end
  end
end

-- midi in 
midi_event = function(data)
  local m = midi.to_msg(data)

  if m.type == "note_on" then
    local voice_space = utils.find_empty_space(voices)

    if voice_space ~= false then
      local voice_sequence = sequences[params:get('hs_v'..voice_space..'_sequence')]
      if voice_sequence.steps == nil then
        local random_i = math.random(1, #sequences - 1)
        voice_sequence = sequences[random_i]
      end
      voices[voice_space]["note"] = m.note
      voices[voice_space]["available"] = false
      voices[voice_space]["clock"] = clock.run(play_sequence, voice_sequence.steps ,voice_space, m.vel)
    end
  elseif m.type == "note_off" then
    for k, v in pairs(voices) do
      if v["note"] == m.note then
        if params:get('hs_hold') == 0 then
          -- if hold isn't on, kill the voice
          note_utils.release_note(k)
        else
          -- or else mark the voice to be released when hold turned off
          voices[k]["hold_release"] = true
        end
      end
    end
  end
end

midi_in.event = midi_event

-- toggle settings
function toggle_shift()
  shift = not shift
  redraw()
end

function toggle_hold()
  if params:get('hs_hold') == 1 then
    params:set('hs_hold', 0)
    hold_release()
  else
    params:set('hs_hold', 1)
  end
  redraw()
end

-- interface things
function key(n,z)
  key_actions.init(n,z)
end

function enc(n,d)
  encoder_actions.init(n,d)
end

function redraw()
  screen.clear()

  -- main screen
  if pages.index == 1 then 
    interface.draw_clock_div()
    interface.draw_gate()
    interface.draw_hold()
    interface.draw_activity()
    interface.draw_lfo()  -- New LFO display
    if shift == true and params:get('hs_output') == 1 then
      interface.draw_channels()
    else
      interface.draw_sequences()
    end
  end

  screen.update()
end

function init()
  engine.cutoff(1000)

  norns.enc.sens(1,16)
  norns.enc.sens(2,16)
  norns.enc.sens(3,16)

  parameters.init()
  
  midi_in = midi.connect(params:get('hs_midi_input'))
  midi_out = midi.connect(params:get('hs_midi_output'))
  
  -- Start LFO clock with a slower refresh rate
  clock.run(function()
    while true do
      clock.sleep(1/15) -- Reduced from 100Hz to 15Hz, still smooth but less CPU intensive
      if params:get("hs_lfo_enable") == 1 then
        lfo.phase = (lfo.phase + params:get("hs_lfo_rate") * (1/15)) % 1
        -- Only redraw if we're showing LFO parameters
        if selected > #voices + 2 then
          redraw()
        end
      end
    end
  end)
end

function cleanup()
  params:write()
  note_utils.kill_all()
  crow.ii.jf.mode(0)
end