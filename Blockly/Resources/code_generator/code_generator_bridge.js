CodeGeneratorBridge = {}

CodeGeneratorBridge.initFactory = function(elem) {
  return function() {
    this.jsonInit(elem);
  };
}

CodeGeneratorBridge.importBlockDefinitions = function(definitions) {
  if (!!definitions) {
    var jsonArr = JSON.parse(definitions);
    for (var index = 0; index < jsonArr.length; index++) {
      var elem = jsonArr[index];
      Blockly.Blocks[elem.id] = {
        init: CodeGeneratorBridge.initFactory(elem)
      };
    }
  }
}

CodeGeneratorBridge.generateCodeForWorkspace = function(workspaceXML, generator) {
  // Parse the XML into a tree.
  var dom = Blockly.Xml.textToDom(workspaceXML);

  // Create a headless workspace.
  var workspace = new Blockly.Workspace();
  Blockly.Xml.domToWorkspace(workspace, dom);

  // Generate the code
  var code = generator.workspaceToCode(workspace);

  // Clear workspace (this will clear any global state that was set)
  workspace.clear();

  return code;
}
