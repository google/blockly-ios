'use strict';

// This is defined to automatically throw a JS exception if an infinite loop is detected.
//Blockly.JavaScript.INFINITE_LOOP_TRAP = 'if(--window.LoopTrap == 0) throw "Infinite loop.";\n';

// Generators for blocks defined in `sound_blocks.json`.
Blockly.JavaScript['play_sound'] = function(block) {
  var value = '\'' + block.getFieldValue('VALUE') + '\'';
  return 'MusicMaker.playSound(' + value + ');\n';
};
