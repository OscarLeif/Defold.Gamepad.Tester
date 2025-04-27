local M = {}
local bit = require("bit") -- Lua bitwise ops

-- Buttons
M.BUTTON_A = 1
M.BUTTON_B = 2
M.BUTTON_C = 3
M.BUTTON_X = 4
M.BUTTON_L1 = 5
M.BUTTON_R1 = 6
M.BUTTON_Y = 7
M.BUTTON_Z = 8
M.BUTTON_L2 = 9
M.BUTTON_R2 = 10
M.DPAD_CENTER = 11
M.DPAD_DOWN = 12
M.DPAD_LEFT = 13
M.DPAD_RIGHT = 14
M.DPAD_UP = 15
M.BUTTON_START = 16
M.BUTTON_SELECT = 17
M.BUTTON_THUMBL = 18
M.BUTTON_THUMBR = 19
M.BUTTON_MODE = 20

-- Hat bitmask
-- Define the bitmask values for each DPAD direction
M.HAT_UP = 0x01
M.HAT_RIGHT = 0x02
M.HAT_DOWN = 0x04
M.HAT_LEFT = 0x08

-- Define axis indexes (joysticks and trigger buttons)
M.LEFT_JOYSTICK_HORIZONTAL = 1
M.LEFT_JOYSTICK_VERTICAL = 2
M.RIGHT_JOYSTICK_HORIZONTAL = 3
M.RIGHT_JOYSTICK_VERTICAL = 4
M.L2 = 5
M.R2 = 6
-- Axis dead zone threshold (ignore small movements)
local DEAD_ZONE = 0.2

-- Define the DPAD index
local DPAD_HAT_INDEX = 1

local current_hats = {}
local previous_hats = {}

local current_buttons = {}
local previous_buttons = {}

local current_axis = {}
local previous_axis = {}

function M.init()
    for i = 1, 32 do
        current_buttons[i] = 0
        previous_buttons[i] = 0

        current_axis[i] = 0
        previous_axis[i] = 0
    end

    for i = 1 , 4 do
        current_hats[i] = 0
        previous_hats[i] = 0
    end

end

function M.on_input(action_id, action)
    local sys_info = sys.get_sys_info()    
    if sys_info.system_name == "Android" and action_id == hash("raw") then
        local button_states = action.gamepad_buttons or {}
        local axis_states = action.gamepad_axis or {}
        local hat_states = action.gamepad_hats or {}

        --read button states and axis_states
        for i = 1, 32 do
            current_buttons[i] = button_states[i] or 0
        end
        
        -- read axis and round almost close to 0 values
        local small_threshold = 0.05
        for i = 1, #axis_states do  -- Assuming axis_states is a table with all axis values
            local axis_value = axis_states[i] or 0
            -- Set axis value to 0 if it is too small (near zero)
            if math.abs(axis_value) < small_threshold then
                current_axis[i] = 0
            else
                current_axis[i] = axis_value
            end
        end

        --read the hat states
        for i = 1, 4 do
            current_hats[i] = hat_states[i] or 0
        end
    end
end

function M.update(dt)
    -- Ensure `previous_*` values are updated with current ones before reading new input
    for i = 1, 32 do
        previous_buttons[i] = current_buttons[i] or 0
        previous_axis[i] = current_axis[i] or 0
    end

    -- Update hats (DPAD)
    for i = 1, 4 do
        previous_hats[i] = current_hats[i] or 0
    end
end

-- Button helpers
function M.is_pressed(button_index)
    return (current_buttons[button_index] or 0) > 0.5
end

function M.was_pressed(button_index)
    local was = (previous_buttons[button_index] or 0) > 0.5
    local now = (current_buttons[button_index] or 0) > 0.5
    return not was and now
end

function M.was_released(button_index)
    local was = (previous_buttons[button_index] or 0) > 0.5
    local now = (current_buttons[button_index] or 0) > 0.5
    return was and not now
end

---HATS
-- Function to check if a specific hat direction is held
function M.is_hat_held(hat_bitmask)
    return bit.band(current_hats[DPAD_HAT_INDEX], hat_bitmask) ~= 0
end

-- Function to check if a specific hat direction was pressed down (newly pressed)
function M.was_hat_held(hat_bitmask)
    local now = bit.band(current_hats[DPAD_HAT_INDEX], hat_bitmask) ~= 0
    local before = bit.band(previous_hats[DPAD_HAT_INDEX], hat_bitmask) ~= 0
    return now and not before
end

-- Function to check if a specific hat direction was released (previously held but released now)
function M.was_hat_released(hat_bitmask)
    local now = bit.band(current_hats[DPAD_HAT_INDEX], hat_bitmask) ~= 0
    local before = bit.band(previous_hats[DPAD_HAT_INDEX], hat_bitmask) ~= 0
    return before and not now
end

--Axis 
-- Function to get the value of the axis (range for joysticks: -1 to 1, range for triggers: 0 to 1)
function M.get_axis_value(axis_index)
    return current_axis[axis_index] or 0  -- Return the current value of the axis, fallback to 0 if nil
end

-- Function to check if an axis moved left this frame (was down)
function M.was_axis_left(axis_index)
    -- Check if it was previously in a non-negative state and is now negative (moved left)
    return M.get_axis_value(axis_index) < -DEAD_ZONE and previous_axis[axis_index] >= -DEAD_ZONE
end

-- Function to check if an axis moved right this frame (was up)
function M.was_axis_right(axis_index)
    -- Check if it was previously in a negative state and is now positive (moved right)
    return M.get_axis_value(axis_index) > DEAD_ZONE and previous_axis[axis_index] <= DEAD_ZONE
end

-- Function to check if an axis moved up this frame (was down)
function M.was_axis_up(axis_index)
    -- Check if it was previously in a non-positive state and is now positive (moved up)
    return M.get_axis_value(axis_index) > DEAD_ZONE and previous_axis[axis_index] <= DEAD_ZONE
end

-- Function to check if an axis moved down this frame (was up)
function M.was_axis_down(axis_index)
    local current_value = M.get_axis_value(axis_index)
    local previous_value = previous_axis[axis_index] or 0  -- Fallback to 0 if nil
    -- created to debug it was like above method
    -- Debugging the current and previous values
    -- print("Axis " .. axis_index .. " current value: " .. current_value)
    -- print("Axis " .. axis_index .. " previous value: " .. previous_value)

    -- Adding a small threshold for values that are close to zero after release
    local small_threshold = 0.05  -- A small threshold for values near zero

    -- Check if the current value is sufficiently negative and previously it was in a neutral or positive state
    return current_value < -DEAD_ZONE and (previous_value >= DEAD_ZONE or math.abs(previous_value) < small_threshold)
end

-- Function to check if trigger buttons (L2 or R2) are pressed
function M.is_trigger_pressed(axis_index)
    return current_axis[axis_index] > 0.5 -- Trigger buttons usually go from 0 to 1, so 0.5 is a good threshold
end

-- UI navigation specific checks (left, right, up, down) for axis movements and DPAD (HAT) directions
function M.was_axis_or_hat_left()
    return M.was_axis_left(M.LEFT_JOYSTICK_HORIZONTAL) or M.was_hat_held(M.HAT_LEFT) or M.was_pressed(M.DPAD_LEFT)
end

function M.was_axis_or_hat_right()
    return M.was_axis_right(M.LEFT_JOYSTICK_HORIZONTAL) or M.was_hat_held(M.HAT_RIGHT)or M.was_pressed(M.DPAD_RIGHT)
end

function M.was_axis_or_hat_up()
    return M.was_axis_up(M.LEFT_JOYSTICK_VERTICAL) or M.was_hat_held(M.HAT_UP)or M.was_pressed(M.DPAD_UP)
end

function M.was_axis_or_hat_down()
    return M.was_axis_down(M.LEFT_JOYSTICK_VERTICAL) or M.was_hat_held(M.HAT_DOWN)or M.was_pressed(M.DPAD_DOWN)
end

function M.submit_ui_action()
    return M.was_pressed(M.BUTTON_A) or M.was_pressed(M.DPAD_CENTER)
end


return M