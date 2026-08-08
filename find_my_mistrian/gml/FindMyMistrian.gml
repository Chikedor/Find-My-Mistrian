// Find My Mistrian
// Fields of Mistria 1.0.x / MOMI + MMAPI 0.14.1+

#macro FIND_MY_MISTRIAN_CONFIG_VERSION 1
#macro FIND_MY_MISTRIAN_VERSION "0.1.0"

function __find_my_mistrian_runtime() {
    if (global[$ "__find_my_mistrian"] == undefined) {
        global.__find_my_mistrian = {
            registered: false,
            initialized: false,
            config: undefined,
            hotkey_registered: false,
            pending_map_npc_id: undefined,
            highlight_node: undefined,
            highlight_original_alpha: 1,
            highlight_ends_at: 0,
        };
    }
    return global.__find_my_mistrian;
}

function find_my_mistrian_config() {
    var _rt = __find_my_mistrian_runtime();
    if (_rt.config != undefined) {
        return _rt.config;
    }

    var _source = mmapi_config_read_valid("find_my_mistrian", FIND_MY_MISTRIAN_CONFIG_VERSION);
    var _hotkey = mmapi_config_get(_source, "hotkey", "F6");
    if (!is_string(_hotkey) || mmapi_hotkey_vk_from_name(_hotkey) == undefined) {
        _hotkey = "F6";
    }

    _rt.config = {
        enabled: mmapi_config_bool(_source, "enabled", true),
        highlight_duration: mmapi_config_number(_source, "highlight_duration", 4, 1, 10),
        open_map_after_locating: mmapi_config_bool(_source, "open_map_after_locating", true),
        hotkey: _hotkey,
        debug_logging: mmapi_config_bool(_source, "debug_logging", false),
    };
    mmapi_config_write(
        "find_my_mistrian",
        FIND_MY_MISTRIAN_CONFIG_VERSION,
        _rt.config,
    );
    return _rt.config;
}

function find_my_mistrian_debug(_message) {
    if (find_my_mistrian_config().debug_logging) {
        mmapi_log_debug("find_my_mistrian", "[FMM] " + _message);
    }
}

function find_my_mistrian_register() {
    var _rt = __find_my_mistrian_runtime();
    if (_rt.registered) {
        return;
    }
    _rt.registered = true;

    mmapi_on("ui.menu_opened", find_my_mistrian_on_menu_opened);
    mmapi_on("ui.menu_closed", find_my_mistrian_on_menu_closed);
    mmapi_register(find_my_mistrian_tick);
}

function find_my_mistrian_tick() {
    var _rt = __find_my_mistrian_runtime();

    if (!_rt.initialized) {
        _rt.initialized = true;
        var _cfg = find_my_mistrian_config();
        var _vk = mmapi_hotkey_vk_from_name(_cfg.hotkey);
        if (_vk != undefined) {
            mmapi_hotkey_register(_vk, find_my_mistrian_on_hotkey);
            _rt.hotkey_registered = true;
        }
        mmapi_log_info(
            "find_my_mistrian",
            "[FMM] Ready. Live location source: NPCS[npc_id].location_position",
        );
    }

    if (_rt.highlight_node == undefined) {
        return;
    }
    if (_rt.highlight_node.freed || current_time() >= _rt.highlight_ends_at) {
        find_my_mistrian_clear_highlight();
        return;
    }

    var _pulse = 0.35 + (0.65 * abs(sin(current_time() / 115)));
    _rt.highlight_node.set_alpha(_pulse);
}

function find_my_mistrian_on_hotkey() {
    var _cfg = find_my_mistrian_config();
    if (!_cfg.enabled || !instance_exists(obj_ari) || is_menu_room(room())) {
        return;
    }

    var _journal = ANCHOR.get_menu(Menu.Journal);
    if (_journal == undefined && game_paused()) {
        return;
    }
    if (_journal == undefined) {
        _journal = ANCHOR.spawn_menu(Menu.Journal);
    }
    if (_journal != undefined) {
        _journal.set_active_sub_menu(Menu.Relationships);
    }
}

function find_my_mistrian_on_menu_opened(_ctx) {
    var _cfg = find_my_mistrian_config();
    if (!_cfg.enabled) {
        return;
    }

    if (_ctx.kind == Menu.Relationships) {
        find_my_mistrian_decorate_relationships(_ctx.menu);
    } else if (_ctx.kind == Menu.Map) {
        find_my_mistrian_apply_pending_map_focus(_ctx.menu);
    }
}

function find_my_mistrian_on_menu_closed(_ctx) {
    if (_ctx.kind == Menu.Map) {
        find_my_mistrian_clear_highlight();
    }
}

function find_my_mistrian_get_known_npcs() {
    var _known = [];
    for (var _npc_id = 0; _npc_id < NpcId.LEN; _npc_id++) {
        if (npc_is_unlocked(_npc_id) && NPCS[_npc_id].has_met()) {
            array_push(_known, _npc_id);
        }
    }
    return _known;
}

function find_my_mistrian_get_npc_location(_npc_id) {
    if (!is_real(_npc_id)
        || _npc_id < 0
        || _npc_id >= NpcId.LEN
        || !npc_is_unlocked(_npc_id)
        || !NPCS[_npc_id].has_met())
    {
        return undefined;
    }

    var _position = NPCS[_npc_id].location_position;
    if (!is_struct(_position)
        || !is_real(_position.location_id)
        || _position.location_id < 0
        || _position.location_id >= LocationId.LEN)
    {
        return undefined;
    }

    var _location = LOCATIONS[_position.location_id];
    if (!is_struct(_location)) {
        return undefined;
    }

    return {
        npc_id: _npc_id,
        position: _position,
        location_id: _position.location_id,
        map_location_id: _location.map_location,
    };
}

function find_my_mistrian_get_location_display_name(_location_result) {
    if (!is_struct(_location_result)) {
        return undefined;
    }

    var _location = LOCATIONS[_location_result.location_id];
    if (_location.name != undefined) {
        return {
            key: _location.name,
            text: mmapi_local_get(_location.name),
            source: "location.name",
        };
    }

    // Interior subrooms often omit a name. Reuse the localized name of the
    // first room in the same vanilla building instead of exposing an id.
    if (_location.building != undefined) {
        for (var _i = 0; _i < LocationId.LEN; _i++) {
            var _candidate = LOCATIONS[_i];
            if (is_struct(_candidate)
                && _candidate.building == _location.building
                && _candidate.name != undefined)
            {
                return {
                    key: _candidate.name,
                    text: mmapi_local_get(_candidate.name),
                    source: "building.name",
                };
            }
        }
    }

    var _map_location = LOCATIONS[_location.map_location];
    if (is_struct(_map_location) && _map_location.name != undefined) {
        return {
            key: _map_location.name,
            text: mmapi_local_get(_map_location.name),
            source: "map_location.name",
        };
    }

    return undefined;
}

function find_my_mistrian_decorate_relationships(_menu) {
    if (_menu[$ "__find_my_mistrian_decorated"] == true) {
        return;
    }
    _menu[$ "__find_my_mistrian_decorated"] = true;

    // The vanilla page leaves its header and a one-button strip between the
    // portrait/details area and the bottom fields unused. Keep the decoration
    // inside those gaps so it does not cover relationship information.
    var _root = ANCHOR.positional(_menu.journal.right_full_body)
        .set_size(174, 138);

    var _label = ANCHOR.text(_root)
        .set_key("mods/find_my_mistrian/ui/current_location")
        .set_lut(COMMON_LUT, CommonLutIndex.Dark)
        .set_align(Align.LeftIn, Align.TopIn)
        .set_xy(1, 0);

    var _value = ANCHOR.text(_root)
        .set_lut(COMMON_LUT, CommonLutIndex.Green)
        .set_align(Align.LeftIn, Align.TopIn)
        .set_xy(1, 10)
        .set_max_width(172)
        .prevent_spillover();

    var _button = ANCHOR.nine_slice(_root)
        .set_size(116, COMMON_BUTTON_HEIGHT)
        .set_align(Align.Center, Align.TopIn)
        .set_y(118)
        .set_sprites_from_key("spr_ui_button")
        .add_text_label(
            "mods/find_my_mistrian/ui/locate_on_map",
            COMMON_LUT,
            CommonLutIndex.Dark,
        )
        .add_hover_outline()
        .add_to_pilot(_menu.pilot, true)
        .set_tap_callback(function(_relationships_menu) {
            find_my_mistrian_locate(_relationships_menu.npc_id_current);
        }, [_menu]);

    _root.board_set("last_npc_id", undefined);
    _root.set_think_callback(function(_status_root, _relationships_menu, _location_value, _locate_button) {
        if (_status_root.board_get("last_npc_id") == _relationships_menu.npc_id_current) {
            return;
        }
        _status_root.board_set("last_npc_id", _relationships_menu.npc_id_current);

        var _location_result = find_my_mistrian_get_npc_location(_relationships_menu.npc_id_current);
        var _display = find_my_mistrian_get_location_display_name(_location_result);
        if (_display == undefined) {
            _location_value.set_key("mods/find_my_mistrian/ui/cannot_locate");
            _locate_button.set_unlocked(false);
            _locate_button.set_alpha(UI_FADE_ALPHA);
        } else {
            _location_value.set_text(_display.text);
            _locate_button.set_unlocked(true);
            _locate_button.set_alpha(1);
        }
    }, [_root, _menu, _value, _button]);

    // Run once immediately; later work is only an integer comparison when the
    // selected relationship entry has not changed.
    _root.board_set("last_npc_id", -1);
}

function find_my_mistrian_locate(_npc_id) {
    var _location_result = find_my_mistrian_get_npc_location(_npc_id);
    var _display = find_my_mistrian_get_location_display_name(_location_result);
    if (_location_result == undefined || _display == undefined) {
        create_notification("mods/find_my_mistrian/ui/cannot_locate");
        return;
    }

    find_my_mistrian_debug("Selected NPC: " + npc_id_to_string(_npc_id));
    find_my_mistrian_debug("NPC location source: NPCS[npc_id].location_position");
    find_my_mistrian_debug("Current area: " + location_id_to_string(_location_result.location_id));

    var _cfg = find_my_mistrian_config();
    if (!_cfg.open_map_after_locating) {
        create_notification(ANCHOR.wrap_for_local(
            local_get(NPC_PROTOTYPES[_npc_id].name) + ": " + _display.text,
        ));
        return;
    }

    var _rt = __find_my_mistrian_runtime();
    _rt.pending_map_npc_id = _npc_id;
    var _journal = ANCHOR.get_menu(Menu.Journal);
    if (_journal == undefined) {
        _journal = ANCHOR.spawn_menu(Menu.Journal);
    }
    if (_journal != undefined) {
        _journal.set_active_sub_menu(Menu.Map);
    }
}

function find_my_mistrian_apply_pending_map_focus(_map_menu) {
    var _rt = __find_my_mistrian_runtime();
    var _npc_id = _rt.pending_map_npc_id;
    _rt.pending_map_npc_id = undefined;
    if (_npc_id == undefined) {
        return;
    }

    var _location_result = find_my_mistrian_get_npc_location(_npc_id);
    if (_location_result == undefined) {
        return;
    }

    _map_menu.select_location(_location_result.map_location_id);
    find_my_mistrian_highlight_icon(_map_menu, _npc_id);
}

function find_my_mistrian_find_sprite_node(_node, _sprite) {
    if (_node.type == NodeId.Sprite && _node.sprite == _sprite) {
        return _node;
    }
    for (var _i = 0; _i < array_length(_node.children); _i++) {
        var _found = find_my_mistrian_find_sprite_node(_node.children[_i], _sprite);
        if (_found != undefined) {
            return _found;
        }
    }
    return undefined;
}

function find_my_mistrian_highlight_icon(_map_menu, _npc_id) {
    find_my_mistrian_clear_highlight();
    var _icon = find_my_mistrian_find_sprite_node(
        _map_menu.map,
        get_small_npc_icon(_npc_id),
    );
    find_my_mistrian_debug("Map icon resolved: " + string(_icon != undefined));
    if (_icon == undefined) {
        return;
    }

    var _rt = __find_my_mistrian_runtime();
    _rt.highlight_node = _icon;
    _rt.highlight_original_alpha = _icon.alpha;
    _rt.highlight_ends_at = current_time()
        + (find_my_mistrian_config().highlight_duration * 1000);
}

function find_my_mistrian_clear_highlight() {
    var _rt = __find_my_mistrian_runtime();
    if (_rt.highlight_node != undefined && !_rt.highlight_node.freed) {
        _rt.highlight_node.set_alpha(_rt.highlight_original_alpha);
    }
    _rt.highlight_node = undefined;
    _rt.highlight_original_alpha = 1;
    _rt.highlight_ends_at = 0;
}

mmapi_mod_declare("find_my_mistrian", FIND_MY_MISTRIAN_VERSION);
find_my_mistrian_register();
