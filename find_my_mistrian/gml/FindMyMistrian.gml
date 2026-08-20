// Find My Mistrian
// Fields of Mistria 1.0.x / MOMI + MMAPI 0.15.6+

#macro FIND_MY_MISTRIAN_CONFIG_VERSION 1
#macro FIND_MY_MISTRIAN_VERSION "0.2.4"

// Layout values are local to their vanilla anchors, never screen coordinates.
#macro FMM_RELATION_LOCATION_BUTTON_HEIGHT 20
#macro FMM_RELATION_LOCATION_Y_OFFSET 5
#macro FMM_QUEST_LOCATE_ELEMENT_HEIGHT 28
#macro FMM_QUEST_LOCATE_BUTTON_WIDTH 128
#macro FMM_QUEST_LOCATE_BUTTON_HEIGHT 20
#macro FMM_HIGHLIGHT_RESOLVE_MAX_ATTEMPTS 30

function __find_my_mistrian_runtime() {
    if (global[$ "__find_my_mistrian"] == undefined) {
        global.__find_my_mistrian = {
            registered: false,
            initialized: false,
            config: undefined,
            hotkey_registered: false,
            pending_map_npc_id: undefined,
            pending_map_source: undefined,
            pending_highlight_map_root: undefined,
            pending_highlight_npc_id: undefined,
            pending_highlight_attempts: 0,
            pending_highlight_started_at: 0,
            pending_highlight_ends_at: 0,
            highlight_node: undefined,
            highlight_map_root: undefined,
            highlight_npc_id: undefined,
            highlight_original_alpha: 1,
            highlight_started_at: 0,
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
    if (!is_string(_hotkey) || mmapi_hotkey_binding_from_name(_hotkey) == undefined) {
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
        // The mod-level switch is explicit user consent for diagnostics. Log
        // at Info so MMAPI's default global Info threshold does not discard
        // the line before it reaches this mod's buffer.
        mmapi_log_info("find_my_mistrian", "[FMM] " + _message);
    }
}

function find_my_mistrian_debug_flush() {
    if (find_my_mistrian_config().debug_logging && mmapi_io_is_ready()) {
        // MMAPI batches Info/Debug lines in groups of 20. A locate attempt is
        // infrequent and must be inspectable immediately after it fails.
        mmapi_log_flush("find_my_mistrian");
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
        var _binding = mmapi_hotkey_binding_from_name(_cfg.hotkey);
        if (_binding != undefined) {
            mmapi_hotkey_register_binding(_binding, find_my_mistrian_on_hotkey);
            _rt.hotkey_registered = true;
        }
        mmapi_log_info(
            "find_my_mistrian",
            "[FMM] Ready. Live location source: NPCS[npc_id].location_position",
        );
        find_my_mistrian_debug_flush();
    }

    find_my_mistrian_process_pending_highlight();

    if (_rt.highlight_node == undefined) {
        return;
    }
    if (_rt.highlight_node.freed) {
        find_my_mistrian_reacquire_highlight("node_freed");
        return;
    }
    if (current_time() >= _rt.highlight_ends_at) {
        find_my_mistrian_clear_highlight("duration_complete");
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
    } else if (_ctx.kind == Menu.QuestLog) {
        find_my_mistrian_decorate_quest_log(_ctx.menu);
    } else if (_ctx.kind == Menu.Map) {
        find_my_mistrian_apply_pending_map_focus(_ctx.menu);
    }
}

function find_my_mistrian_on_menu_closed(_ctx) {
    if (_ctx.kind == Menu.Map) {
        find_my_mistrian_cancel_pending_highlight("map_closed");
        find_my_mistrian_clear_highlight("map_closed");
    }
}

function find_my_mistrian_get_known_npcs() {
    var _known = [];
    for (var _npc_id = 0; _npc_id < NpcId.LEN; _npc_id++) {
        if (find_my_mistrian_has_player_met_npc(_npc_id)) {
            array_push(_known, _npc_id);
        }
    }
    return _known;
}

// Vanilla writes this exact T2R-backed state after a valid first conversation.
// It is also the gate Relationships uses for names, portraits, and selection.
function find_my_mistrian_has_player_met_npc(_npc_id) {
    return is_real(_npc_id)
        && _npc_id >= 0
        && _npc_id < NpcId.LEN
        && npc_is_unlocked(_npc_id)
        && NPCS[_npc_id].has_met();
}

function find_my_mistrian_get_npc_location(_npc_id) {
    if (!find_my_mistrian_has_player_met_npc(_npc_id)) {
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

    // The vanilla polaroid is the stable layout anchor. Its bottom edge stays
    // above field_zone at every supported language/layout variant.
    var _root = ANCHOR.positional(_menu.polaroid.background)
        .set_size(_menu.polaroid.background.get_size());

    var _location_pilot = _menu.new_pilot();
    _menu.pilot.set_neighbor(_location_pilot, Cardinal.East);
    _location_pilot.set_neighbor(_menu.pilot, Cardinal.West);

    var _button = ANCHOR.nine_slice(_root)
        .set_size(_menu.polaroid.background.get_width(), FMM_RELATION_LOCATION_BUTTON_HEIGHT)
        .set_align(Align.Center, Align.BottomOut)
        .set_y(FMM_RELATION_LOCATION_Y_OFFSET)
        .set_sprites_from_key("spr_ui_button")
        .add_text_label(
            "mods/find_my_mistrian/ui/unknown_location",
            COMMON_LUT,
            CommonLutIndex.Dark,
        )
        .add_hover_outline()
        .add_to_pilot(_location_pilot)
        .set_tap_callback(function(_relationships_menu) {
            find_my_mistrian_locate_npc_on_map(
                _relationships_menu.npc_id_current,
                "relationships",
            );
        }, [_menu]);

    _button.text_label
        .set_x(4)
        .set_max_width(_button.get_width() - 16)
        .prevent_spillover();

    ANCHOR.sprite(_button)
        .set_sprite(spr_ui_journal_magic_pin_icon)
        .set_align(Align.LeftIn, Align.Middle)
        .set_x(4);

    _button.set_think_callback(function(_location_button, _relationships_menu) {
        find_my_mistrian_show_locate_action_hint(
            _location_button,
            _relationships_menu.npc_id_current,
        );
    }, [_button, _menu]);

    _root.board_set("last_npc_id", undefined);
    _root.set_think_callback(function(_status_root, _relationships_menu, _location_button) {
        if (_status_root.board_get("last_npc_id") == _relationships_menu.npc_id_current) {
            return;
        }
        _status_root.board_set("last_npc_id", _relationships_menu.npc_id_current);

        if (!find_my_mistrian_has_player_met_npc(_relationships_menu.npc_id_current)) {
            _location_button.set_unlocked(false);
            _location_button.disable();
            return;
        }

        _location_button.enable();
        var _location_result = find_my_mistrian_get_npc_location(_relationships_menu.npc_id_current);
        var _display = find_my_mistrian_get_location_display_name(_location_result);
        if (_display == undefined) {
            _location_button.text_label.set_key("mods/find_my_mistrian/ui/unknown_location");
            _location_button.set_unlocked(false);
            _location_button.set_alpha(UI_FADE_ALPHA);
        } else {
            _location_button.text_label.set_text(_display.text);
            _location_button.set_unlocked(true);
            _location_button.set_alpha(1);
        }
    }, [_root, _menu, _button]);

    // Run once immediately; later work is only an integer comparison when the
    // selected relationship entry has not changed.
    _root.board_set("last_npc_id", -1);
}

function find_my_mistrian_show_locate_action_hint(_button, _npc_id) {
    if (!_button.is_unlocked()
        || !find_my_mistrian_has_player_met_npc(_npc_id)
        || !(_button.is_hovered() || _button.is_selected()))
    {
        return;
    }

    var _hint = format(
        "{Local} {Local} {Local}",
        "mods/find_my_mistrian/ui/locate_npc_prefix",
        NPC_PROTOTYPES[_npc_id].name,
        "mods/find_my_mistrian/ui/on_map_suffix",
    );
    GLYPH_GUIDE.set_input(InputId.Interact, ANCHOR.wrap_for_local(_hint));
}

function find_my_mistrian_get_current_quest_target(_quest_menu) {
    if (_quest_menu.context != QuestLogContext.Journal
        || _quest_menu.active_quest == undefined)
    {
        return undefined;
    }

    var _active = QUEST_LOG.active.get(_quest_menu.active_quest);
    if (_active == undefined
        || _active.current_stage < 0
        || _active.current_stage >= _active.quest.tasks.count())
    {
        return undefined;
    }

    var _task = _active.quest.tasks.get(_active.current_stage);

    // Vanilla only exposes an NPC quest interaction once every requirement
    // for the active task passes. Match that gate so collection-only phases
    // do not prematurely display a locator.
    if (!fulfills_all_requirements(_task.requirements, _active.blackboard)) {
        return undefined;
    }

    var _target = undefined;
    for (var _i = 0; _i < _task.query_targets.count(); _i++) {
        var _query = _task.query_targets.get(_i);
        if (_query.type != QuestQueryType.Npc) {
            continue;
        }

        // Be conservative if future content introduces an ambiguous stage.
        if (_target != undefined && _target != _query.npc_name) {
            return undefined;
        }
        _target = _query.npc_name;
    }

    return find_my_mistrian_has_player_met_npc(_target) ? _target : undefined;
}

function find_my_mistrian_quest_button_key(_npc_id) {
    return ANCHOR.wrap_for_local(format(
        "{Local} {Local}",
        "mods/find_my_mistrian/ui/locate_npc_prefix",
        NPC_PROTOTYPES[_npc_id].name,
    ));
}

function find_my_mistrian_move_quest_control_before_rewards(_scroller, _element) {
    var _children = _scroller.root.children;
    var _element_index = array_pos(_children, _element);
    var _rewards_index = -1;

    for (var _i = 0; _i < _element_index; _i++) {
        var _candidate = _children[_i];
        if (_candidate.text_label != undefined
            && _candidate.text_label.get_display_key() == "misc_local/rewards")
        {
            _rewards_index = _i;
            break;
        }
    }

    if (_rewards_index < 0) {
        return;
    }

    var _spacing = _element.get_height() - 1;
    var _target_y = _children[_rewards_index].get_y();
    for (var _i = _rewards_index; _i < _element_index; _i++) {
        _children[_i].add_y(_spacing);
    }

    _element.set_y(_target_y);
    array_delete(_children, _element_index, 1);
    array_insert(_children, _rewards_index, _element);
}

function find_my_mistrian_add_quest_locator(_quest_menu, _npc_id) {
    var _scroller = _quest_menu.right_scroller;
    if (_scroller == undefined) {
        return undefined;
    }

    var _element = _scroller.new_element(FMM_QUEST_LOCATE_ELEMENT_HEIGHT)
        .set_sprite(spr_nothing_nineslice);

    var _button = ANCHOR.nine_slice(_element)
        .set_size(FMM_QUEST_LOCATE_BUTTON_WIDTH, FMM_QUEST_LOCATE_BUTTON_HEIGHT)
        .set_align(Align.Center, Align.Middle)
        .set_sprites_from_key("spr_ui_button")
        .add_text_label(
            find_my_mistrian_quest_button_key(_npc_id),
            COMMON_LUT,
            CommonLutIndex.Dark,
        )
        .add_hover_outline()
        .add_to_pilot(_quest_menu.right_pilot, true)
        .set_tap_callback(function(_target_npc_id) {
            find_my_mistrian_locate_npc_on_map(_target_npc_id, "quest");
        }, [_npc_id]);

    _button.text_label
        .set_x(4)
        .set_max_width(FMM_QUEST_LOCATE_BUTTON_WIDTH - 18)
        .prevent_spillover();

    ANCHOR.sprite(_button)
        .set_sprite(spr_ui_journal_magic_pin_icon)
        .set_align(Align.LeftIn, Align.Middle)
        .set_x(5);

    var _location = find_my_mistrian_get_npc_location(_npc_id);
    var _can_locate = find_my_mistrian_get_location_display_name(_location) != undefined;
    _button.set_unlocked(_can_locate);
    _button.set_alpha(_can_locate ? 1 : UI_FADE_ALPHA);

    _button.set_think_callback(function(_quest_button, _target_npc_id) {
        find_my_mistrian_show_locate_action_hint(_quest_button, _target_npc_id);
    }, [_button, _npc_id]);

    // Keep the control in the same scrolling flow, immediately after the
    // objectives block and before the rewards block when one exists.
    find_my_mistrian_move_quest_control_before_rewards(_scroller, _element);

    return {
        element: _element,
        button: _button,
        npc_id: _npc_id,
        scroller: _scroller,
    };
}

function find_my_mistrian_update_quest_locator(_control, _npc_id) {
    if (_control == undefined
        || _control.element.freed
        || _control.button.freed)
    {
        return undefined;
    }

    if (_npc_id == undefined) {
        _control.element.disable();
        _control.button.set_unlocked(false);
        return _control;
    }

    _control.npc_id = _npc_id;
    _control.element.enable();
    _control.button.text_label.set_key(find_my_mistrian_quest_button_key(_npc_id));
    _control.button.set_tap_callback(function(_target_npc_id) {
        find_my_mistrian_locate_npc_on_map(_target_npc_id, "quest");
    }, [_npc_id], true);
    _control.button.set_think_callback(function(_quest_button, _target_npc_id) {
        find_my_mistrian_show_locate_action_hint(_quest_button, _target_npc_id);
    }, [_control.button, _npc_id]);

    var _location = find_my_mistrian_get_npc_location(_npc_id);
    var _can_locate = find_my_mistrian_get_location_display_name(_location) != undefined;
    _control.button.set_unlocked(_can_locate);
    _control.button.set_alpha(_can_locate ? 1 : UI_FADE_ALPHA);
    return _control;
}

function find_my_mistrian_decorate_quest_log(_menu) {
    if (_menu.context != QuestLogContext.Journal
        || _menu[$ "__find_my_mistrian_decorated"] == true)
    {
        return;
    }
    _menu[$ "__find_my_mistrian_decorated"] = true;

    // QuestLog rebuilds right_body internally without emitting
    // ui.menu_refreshed in MOMI 0.15.1. This persistent watcher lives under
    // the journal book, outside right_body, and adds at most one control to
    // each newly-created right scroller.
    var _watcher = ANCHOR.positional(_menu.journal.book).set_size(0, 0);
    _watcher.board_set("last_quest", undefined);
    _watcher.board_set("last_stage", undefined);
    _watcher.board_set("last_scroller", undefined);
    _watcher.board_set("last_target", undefined);
    _watcher.board_set("control", undefined);

    _watcher.set_think_callback(function(_node, _quest_menu) {
        var _active = _quest_menu.active_quest == undefined
            ? undefined
            : QUEST_LOG.active.get(_quest_menu.active_quest);
        var _stage = _active == undefined ? undefined : _active.current_stage;
        var _target = find_my_mistrian_get_current_quest_target(_quest_menu);
        var _scroller = _quest_menu.right_scroller;
        var _location = find_my_mistrian_get_npc_location(_target);
        var _can_locate = find_my_mistrian_get_location_display_name(_location) != undefined;

        if (_node.board_get("last_quest") == _quest_menu.active_quest
            && _node.board_get("last_stage") == _stage
            && _node.board_get("last_scroller") == _scroller
            && _node.board_get("last_target") == _target
            && _node.board_get("last_can_locate") == _can_locate)
        {
            return;
        }

        var _old_scroller = _node.board_get("last_scroller");
        var _control = _node.board_get("control");
        _node.board_set("last_quest", _quest_menu.active_quest);
        _node.board_set("last_stage", _stage);
        _node.board_set("last_scroller", _scroller);
        _node.board_set("last_target", _target);
        _node.board_set("last_can_locate", _can_locate);

        // A stage can advance while this menu remains alive. Reuse the same
        // node when its scroller did not rebuild, so refreshes never stack.
        if (_control != undefined && _old_scroller == _scroller) {
            _node.board_set(
                "control",
                find_my_mistrian_update_quest_locator(_control, _target),
            );
            return;
        }

        _node.board_set("control", undefined);

        if (_target != undefined && _scroller != undefined) {
            _node.board_set(
                "control",
                find_my_mistrian_add_quest_locator(_quest_menu, _target),
            );
        }
    }, [_watcher, _menu]);
}

function find_my_mistrian_locate_npc_on_map(_npc_id, _source) {
    find_my_mistrian_debug(
        "Locate requested: source=" + string(_source)
        + " npc=" + npc_id_to_string(_npc_id)
        + " frame=" + string(TICK),
    );

    var _location_result = find_my_mistrian_get_npc_location(_npc_id);
    var _display = find_my_mistrian_get_location_display_name(_location_result);
    if (_location_result == undefined || _display == undefined) {
        find_my_mistrian_debug("Locate rejected: no usable live location");
        find_my_mistrian_debug_flush();
        create_notification("mods/find_my_mistrian/ui/cannot_locate");
        return;
    }

    find_my_mistrian_debug(
        "Live location resolved: area="
        + location_id_to_string(_location_result.location_id)
        + " map=" + location_id_to_string(_location_result.map_location_id)
        + " dyn_index=" + string(_location_result.position.dyn_index),
    );

    var _cfg = find_my_mistrian_config();
    if (!_cfg.open_map_after_locating) {
        find_my_mistrian_debug("Map opening disabled by configuration");
        find_my_mistrian_debug_flush();
        create_notification(ANCHOR.wrap_for_local(
            local_get(NPC_PROTOTYPES[_npc_id].name) + ": " + _display.text,
        ));
        return;
    }

    var _rt = __find_my_mistrian_runtime();
    _rt.pending_map_npc_id = _npc_id;
    _rt.pending_map_source = _source;
    var _journal = ANCHOR.get_menu(Menu.Journal);
    if (_journal == undefined) {
        find_my_mistrian_debug("Journal absent; spawning vanilla Journal");
        _journal = ANCHOR.spawn_menu(Menu.Journal);
    }
    if (_journal != undefined) {
        find_my_mistrian_debug("Map request queued");
        find_my_mistrian_debug_flush();
        _journal.set_active_sub_menu(Menu.Map);
    } else {
        find_my_mistrian_debug("Map request failed: Journal unavailable");
        find_my_mistrian_debug_flush();
    }
}

function find_my_mistrian_apply_pending_map_focus(_map_menu) {
    var _rt = __find_my_mistrian_runtime();
    var _npc_id = _rt.pending_map_npc_id;
    var _source = _rt.pending_map_source;
    _rt.pending_map_npc_id = undefined;
    _rt.pending_map_source = undefined;
    if (_npc_id == undefined) {
        return;
    }

    find_my_mistrian_debug(
        "Map opened for pending locate: source=" + string(_source)
        + " npc=" + npc_id_to_string(_npc_id)
        + " frame=" + string(TICK),
    );

    var _location_result = find_my_mistrian_get_npc_location(_npc_id);
    if (_location_result == undefined) {
        find_my_mistrian_debug("Pending locate aborted: live location became unavailable");
        find_my_mistrian_debug_flush();
        return;
    }

    var _target_map_id = _location_result.map_location_id;
    if (_map_menu.selected_location_id == _target_map_id) {
        find_my_mistrian_debug(
            "Map region already selected; preserving current icon tree: "
            + location_id_to_string(_target_map_id),
        );
    } else {
        _map_menu.select_location(_target_map_id);
        find_my_mistrian_debug(
            "Map region selected and icon tree rebuilt: "
            + location_id_to_string(_target_map_id),
        );
    }

    // MapMenu.select_location() frees the previous tree lazily. Resolve from
    // the next MMAPI tick, when stale nodes are marked freed, and retry while
    // the replacement tree settles instead of selecting the first duplicate.
    find_my_mistrian_schedule_highlight(_map_menu.map, _npc_id);
}

function find_my_mistrian_find_sprite_node(_node, _sprite) {
    if (_node.freed) {
        return undefined;
    }
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

function find_my_mistrian_count_sprite_nodes(_node, _sprite) {
    if (_node.freed) {
        return 0;
    }
    var _count = (_node.type == NodeId.Sprite && _node.sprite == _sprite) ? 1 : 0;
    for (var _i = 0; _i < array_length(_node.children); _i++) {
        _count += find_my_mistrian_count_sprite_nodes(_node.children[_i], _sprite);
    }
    return _count;
}

function find_my_mistrian_schedule_highlight(_map_root, _npc_id) {
    find_my_mistrian_cancel_pending_highlight("replaced");
    find_my_mistrian_clear_highlight("replaced");
    var _rt = __find_my_mistrian_runtime();
    _rt.pending_highlight_map_root = _map_root;
    _rt.pending_highlight_npc_id = _npc_id;
    _rt.pending_highlight_attempts = 0;
    _rt.pending_highlight_started_at = 0;
    _rt.pending_highlight_ends_at = 0;
    find_my_mistrian_debug(
        "Highlight resolution scheduled for next frame: npc="
        + npc_id_to_string(_npc_id),
    );
    find_my_mistrian_debug_flush();
}

function find_my_mistrian_process_pending_highlight() {
    var _rt = __find_my_mistrian_runtime();
    var _npc_id = _rt.pending_highlight_npc_id;
    if (_npc_id == undefined) {
        return;
    }

    var _map_root = _rt.pending_highlight_map_root;
    if (_map_root == undefined || _map_root.freed) {
        find_my_mistrian_cancel_pending_highlight("map_root_freed");
        return;
    }

    if (_rt.pending_highlight_ends_at > 0
        && current_time() >= _rt.pending_highlight_ends_at)
    {
        find_my_mistrian_debug(
            "Highlight ended while reacquiring: reason=duration_complete"
            + " npc=" + npc_id_to_string(_npc_id)
            + " elapsed_ms="
            + string(current_time() - _rt.pending_highlight_started_at),
        );
        find_my_mistrian_cancel_pending_highlight("duration_complete");
        return;
    }

    _rt.pending_highlight_attempts += 1;
    var _attempt = _rt.pending_highlight_attempts;
    var _sprite = get_small_npc_icon(_npc_id);
    var _match_count = find_my_mistrian_count_sprite_nodes(_map_root, _sprite);
    find_my_mistrian_debug(
        "Map icon resolve attempt=" + string(_attempt)
        + " npc=" + npc_id_to_string(_npc_id)
        + " matches=" + string(_match_count)
    );

    if (_match_count != 1) {
        if (_attempt < FMM_HIGHLIGHT_RESOLVE_MAX_ATTEMPTS) {
            return;
        }
        find_my_mistrian_debug(
            "Highlight resolution exhausted: expected one stable icon",
        );
        find_my_mistrian_cancel_pending_highlight("attempts_exhausted");
        return;
    }

    var _icon = find_my_mistrian_find_sprite_node(_map_root, _sprite);
    if (_icon == undefined || _icon.freed) {
        if (_attempt < FMM_HIGHLIGHT_RESOLVE_MAX_ATTEMPTS) {
            return;
        }
        find_my_mistrian_cancel_pending_highlight("stable_icon_unavailable");
        return;
    }

    var _resume_started_at = _rt.pending_highlight_started_at;
    var _resume_ends_at = _rt.pending_highlight_ends_at;
    _rt.pending_highlight_map_root = undefined;
    _rt.pending_highlight_npc_id = undefined;
    _rt.pending_highlight_attempts = 0;
    _rt.pending_highlight_started_at = 0;
    _rt.pending_highlight_ends_at = 0;

    _rt.highlight_node = _icon;
    _rt.highlight_map_root = _map_root;
    _rt.highlight_npc_id = _npc_id;
    _rt.highlight_original_alpha = _icon.alpha;
    if (_resume_ends_at > current_time()) {
        _rt.highlight_started_at = _resume_started_at;
        _rt.highlight_ends_at = _resume_ends_at;
    } else {
        _rt.highlight_started_at = current_time();
        _rt.highlight_ends_at = current_time()
            + (find_my_mistrian_config().highlight_duration * 1000);
    }
    find_my_mistrian_debug(
        (_resume_ends_at > current_time()
            ? "Highlight resumed on replacement icon: attempt="
            : "Highlight started from stable icon: attempt=")
        + string(_attempt)
        + " x=" + string(_icon.get_x())
        + " y=" + string(_icon.get_y())
        + " alpha=" + string(_rt.highlight_original_alpha)
        + " remaining_ms=" + string(_rt.highlight_ends_at - current_time()),
    );
    find_my_mistrian_debug_flush();
}

function find_my_mistrian_cancel_pending_highlight(_reason) {
    var _rt = __find_my_mistrian_runtime();
    if (_rt.pending_highlight_npc_id == undefined) {
        return;
    }

    find_my_mistrian_debug(
        "Pending highlight cancelled: reason=" + string(_reason)
        + " npc=" + npc_id_to_string(_rt.pending_highlight_npc_id)
        + " attempts=" + string(_rt.pending_highlight_attempts),
    );
    _rt.pending_highlight_map_root = undefined;
    _rt.pending_highlight_npc_id = undefined;
    _rt.pending_highlight_attempts = 0;
    _rt.pending_highlight_started_at = 0;
    _rt.pending_highlight_ends_at = 0;
    find_my_mistrian_debug_flush();
}

function find_my_mistrian_reacquire_highlight(_reason) {
    var _rt = __find_my_mistrian_runtime();
    if (_rt.highlight_node == undefined) {
        return;
    }

    find_my_mistrian_debug(
        "Highlight node invalidated; scheduling reacquisition: reason="
        + string(_reason)
        + " npc=" + npc_id_to_string(_rt.highlight_npc_id)
        + " elapsed_ms=" + string(current_time() - _rt.highlight_started_at),
    );
    _rt.pending_highlight_map_root = _rt.highlight_map_root;
    _rt.pending_highlight_npc_id = _rt.highlight_npc_id;
    _rt.pending_highlight_attempts = 0;
    _rt.pending_highlight_started_at = _rt.highlight_started_at;
    _rt.pending_highlight_ends_at = _rt.highlight_ends_at;
    _rt.highlight_node = undefined;
    _rt.highlight_map_root = undefined;
    _rt.highlight_npc_id = undefined;
    _rt.highlight_original_alpha = 1;
    _rt.highlight_started_at = 0;
    _rt.highlight_ends_at = 0;
    find_my_mistrian_debug_flush();
}

function find_my_mistrian_clear_highlight(_reason) {
    var _rt = __find_my_mistrian_runtime();
    if (_rt.highlight_node == undefined) {
        return;
    }

    if (_rt.highlight_node != undefined && !_rt.highlight_node.freed) {
        _rt.highlight_node.set_alpha(_rt.highlight_original_alpha);
    }
    find_my_mistrian_debug(
        "Highlight ended: reason=" + string(_reason)
        + " npc=" + npc_id_to_string(_rt.highlight_npc_id)
        + " elapsed_ms=" + string(current_time() - _rt.highlight_started_at)
        + " node_freed=" + string(_rt.highlight_node.freed),
    );
    _rt.highlight_node = undefined;
    _rt.highlight_map_root = undefined;
    _rt.highlight_npc_id = undefined;
    _rt.highlight_original_alpha = 1;
    _rt.highlight_started_at = 0;
    _rt.highlight_ends_at = 0;
    find_my_mistrian_debug_flush();
}

mmapi_mod_declare("find_my_mistrian", FIND_MY_MISTRIAN_VERSION);
find_my_mistrian_register();
