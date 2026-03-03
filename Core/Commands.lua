local _, NS = ...
SLASH_BPF1 = "/bpf"
SlashCmdList["BPF"] = function()
    if NS.ToggleGUI then
        NS.ToggleGUI()
    end
end
