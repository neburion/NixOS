''
  @import "themes/active.css";

  * {
      font-family: "FiraMono Nerd Font";
      min-height: 0;
      font-size: 14px;
      padding: 0px;
      margin-top: 1px;
      margin-bottom: 1px;
  }
  #window { background-color: var(--bg); }
  #outer-box { padding: 10px; }
  #input {
      background-color: var(--surface);
      color: var(--fg);
      border-radius: 20px;
      padding: 12px;
  }
  #scroll { margin-top: 10px; margin-bottom: 10px; }
  #text { color: var(--fg); padding-left: 10px; }
  #text:selected { color: var(--fg); }
  #entry { padding: 5px; margin-top: 5px; }
  #entry:selected { background-color: var(--selection); }
  #input, #entry:selected { border-radius: 20px; border: 0px; }
''
