{ ... }:
{
  programs.wofi = {
    enable = true;

    settings = {
      show = "drun";
      prompt = ">";
      normal_window = true;
      layer = "overlay";
      term = "ghostty";
      columns = 1;

      # Geometry
      width = "35%";
      height = "30%";
      location = "center";
      orientation = "vertical";
      halign = "fill";
      line_wrap = "off";
      dynamic_lines = false;

      # Search
      exec_search = false;
      hide_search = false;
      parse_search = false;
      insensitive = false;

      # Other
      hide_scroll = true;
      no_actions = true;
      sort_order = "default";
      gtk_dark = true;
      filter_rate = 100;

      # Keys
      key_expand = "Tab";
      key_exit = "Escape";
    };

    style = ''
      * {
          font-family: "FiraMono Nerd Font";
          min-height: 0;
          font-size: 14px;
          padding: 0px;
          margin-top: 1px;
          margin-bottom: 1px;
      }
      #window {
          background-color: #111111;
      }
      #outer-box {
          padding: 10px;
      }
      #input {
          background-color: #222222;
          color: white;
          border-radius: 20px;
          padding: 12px;
      }
      #scroll {
          margin-top: 10px;
          margin-bottom: 10px;
      }
      #text {
          color: #ffffff;
          padding-left: 10px;
      }
      #text:selected {
          color: #ffffff;
      }
      #entry {
          padding: 5px;
          margin-top: 5px;
      }
      #entry:selected {
          background-color: #333333;
      }
      #input, #entry:selected {
          border-radius: 20px;
          border: 0px;
      }
    '';
  };
}
