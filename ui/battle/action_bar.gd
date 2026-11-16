class_name ActionBar
extends HFlowContainer
## Botones de las acciones del jugador. Cada boton sabe que accion representa;
## la pantalla de combate decide si es legal y que pasa al pulsarlo.

## El jugador pulso una accion que se ejecuta directamente.
signal action_chosen(action: BattleAction)
## El jugador pulso Salto: hay que elegir casilla.
signal teleport_requested
## El raton entro o salio de un boton (action es null al salir).
signal action_hovered(action: BattleAction)

var _buttons: Array[Button] = []
var _actions: Array[BattleAction] = []


func _init() -> void:
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)


## Crea los botones a partir de las piezas del mech del jugador.
func build_for(mech: BattleMech) -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
	_actions.clear()
	for key in mech.weapon_keys():
		_add(BattleAction.weapon(key), _weapon_title(mech.slots[key].def))
	if mech.slots["legs"].def.deals_damage():
		_add(BattleAction.stomp(), _item_title(Txt.t("stomp"), mech.slots["legs"].def))
	if mech.slots.has("charge"):
		_add(BattleAction.charge(), _item_title(Txt.t("charge"), mech.slots["charge"].def))
	if mech.slots.has("hook"):
		_add(BattleAction.hook(), _item_title(Txt.t("hook"), mech.slots["hook"].def))
	if mech.slots.has("teleport"):
		_add(BattleAction.teleport(-1), _item_title(Txt.t("teleport"), mech.slots["teleport"].def))
	_add(BattleAction.cool(), Txt.t("cool"))


## Activa o desactiva cada boton. reason_for(action) devuelve "" si es legal.
func refresh(enabled: bool, reason_for: Callable, uses_left_for: Callable) -> void:
	for i in _buttons.size():
		var action := _actions[i]
		var button := _buttons[i]
		var reason: String = reason_for.call(action) if enabled else " "
		button.disabled = reason != ""
		button.tooltip_text = "" if reason.strip_edges() == "" else Txt.t("illegal", [reason])
		var uses: int = uses_left_for.call(action)
		var base: String = button.get_meta("title")
		button.text = base if uses < 0 else "%s\n%s" % [base, Txt.t("uses", [str(uses)])]


func _add(action: BattleAction, title: String) -> void:
	var button := Button.new()
	button.text = title
	button.set_meta("title", title)
	button.custom_minimum_size = Vector2(150, 62)
	button.add_theme_font_size_override("font_size", 13)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_pressed.bind(action))
	button.mouse_entered.connect(func() -> void: action_hovered.emit(action))
	button.mouse_exited.connect(func() -> void: action_hovered.emit(null))
	add_child(button)
	_buttons.append(button)
	_actions.append(action)


func _on_pressed(action: BattleAction) -> void:
	if action.type == BattleAction.Type.TELEPORT:
		teleport_requested.emit()
	else:
		action_chosen.emit(action)


func _weapon_title(def: ItemDef) -> String:
	return _item_title(def.display_name, def)


func _item_title(title: String, def: ItemDef) -> String:
	var parts: Array[String] = []
	if def.range_max > 0:
		parts.append("%d–%d" % [def.range_min, def.range_max])
	if def.energy_cost > 0:
		parts.append("E%d" % def.energy_cost)
	if def.heat_cost > 0:
		parts.append("C%d" % def.heat_cost)
	return title if parts.is_empty() else "%s\n%s" % [title, " · ".join(parts)]
