/*
 * Copyright 2016 Google Inc. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 This file contains all custom `domToMutation(xmlElement)` functions for known default mutator
 blocks.
 */

CodeGeneratorBridge.BlockDomToMutation["controls_if"] = function(xmlElement) {
  var elseifCount = parseInt(xmlElement.getAttribute('elseif'), 10) || 0;
  var elseCount = parseInt(xmlElement.getAttribute('else'), 10) || 0;

  // Remove existing inputs
  if (this.getInput('ELSE')) {
    this.removeInput('ELSE');
  }
  var i = 1;
  while (this.getInput('IF' + i)) {
    this.removeInput('IF' + i);
    this.removeInput('DO' + i);
    i++;
  }
  // Rebuild block.
  for (var i = 1; i <= elseifCount; i++) {
    this.appendValueInput('IF' + i)
    .setCheck('Boolean')
    .appendField(Blockly.Msg.CONTROLS_IF_MSG_ELSEIF);
    this.appendStatementInput('DO' + i)
    .appendField(Blockly.Msg.CONTROLS_IF_MSG_THEN);
  }
  if (elseCount) {
    this.appendStatementInput('ELSE')
    .appendField(Blockly.Msg.CONTROLS_IF_MSG_ELSE);
  }
};
