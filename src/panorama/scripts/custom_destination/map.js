"use strict";

// When a map part is unlocked
function onMapUnlocked(info) {
    $.Msg('Yes!')

    $.Msg(info)
}

// Scanning for what map parts are visible
function mapScanLoop() {
    // Continue the loop
    $.Schedule(1, mapScanLoop);

    var rootPanel = $.GetContextPanel();

    $.Each($('#mainMapContainer').Children(), function(panel) {
        var panelName = panel.id;

        // Check if it's visible
        panel.visible = rootPanel.BHasClass(panelName);
        panel.SetHasClass('playerInside', rootPanel.BHasClass('inside_' + panelName));
    });
}

// Init
(function() {
    // Render the map
    $.Schedule(0.1, mapScanLoop);
})();
