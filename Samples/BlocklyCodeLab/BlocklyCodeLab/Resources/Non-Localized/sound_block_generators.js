'use strict';

// This is defined to automatically throw a JS exception if an infinite loop is detected.
//Blockly.JavaScript.INFINITE_LOOP_TRAP = 'if(--window.LoopTrap == 0) throw "Infinite loop.";\n';

// Generators for blocks defined in `sound_blocks.json`.
Blockly.JavaScript['sounds_play_sound'] = function(block) {
  var value = Blockly.JavaScript.valueToCode(block, 'SOUND',
    Blockly.JavaScript.ORDER_NONE) || 'null';
  return 'musicMaker.playSound(' + value + ');\n';
};

Blockly.JavaScript['sounds_dropdown'] = function(block) {
  var value = '\'' + block.getFieldValue('VALUE') + '\'';
  return [value, Blockly.JavaScript.ORDER_ATOMIC];
};
