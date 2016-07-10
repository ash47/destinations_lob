-- Define class
local Constants = {}

-- Hand0 Hand VR Buttons
Constants.hand0_dpad = bit.lshift(1, 0)
Constants.hand0_trigger = bit.lshift(1, 1)
Constants.hand0_top_button = bit.lshift(1, 3)
Constants.hand0_grip = bit.lshift(1, 4)

-- Hand1 Hand VR Buttons
Constants.hand1_dpad = bit.lshift(1, 16)
Constants.hand1_trigger = bit.lshift(1, 17)
Constants.hand1_top_button = bit.lshift(1, 19)
Constants.hand1_grip = bit.lshift(1, 20)

-- Items
Constants.item_nothing = 1
Constants.item_sword = 2
Constants.item_shield = 3
Constants.item_key = 4
Constants.item_bow = 5
Constants.item_boomerang = 6
Constants.item_bomb = 7

-- Rewards
Constants.reward_key = 1
Constants.reward_compass = 2
Constants.reward_map = 3
Constants.reward_boomerang = 4

-- Export
return Constants