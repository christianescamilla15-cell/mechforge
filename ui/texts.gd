class_name Txt
extends RefCounted
## Tabla de textos de la interfaz. Todo texto visible pasa por Txt.t(clave),
## para poder anadir otro idioma cambiando solo esta tabla.

const ES := {
	"you": "Tú",
	"rival": "Rival",
	"health": "Vida",
	"heat": "Calor",
	"energy": "Energía",
	"resist": "Res. fís/cal/ene",
	"turn_of": "Turno %d · %s",
	"your_turn": "tu turno",
	"rival_turn": "turno del rival",
	"actions_left": "Acciones: %d",
	"cool": "Enfriar",
	"stomp": "Pisotón",
	"charge": "Embestida",
	"hook": "Garfio",
	"teleport": "Salto",
	"walk_hint": "Haz clic en una casilla marcada para moverte",
	"teleport_hint": "Elige la casilla de destino del salto",
	"range_any": "toda la arena",
	"range": "alcance %d–%d",
	"uses": "usos %s",
	"cost_heat": "calor +%d",
	"cost_energy": "energía −%d",
	"preview_title": "Previsión",
	"preview_damage": "Daño: %d–%d",
	"preview_no_damage": "No hace daño",
	"preview_self": "Tú → calor %d/%d · energía %d/%d",
	"preview_target": "Rival → calor %d/%d · energía %d/%d",
	"preview_self_overheat": "¡Te sobrecalentarás!",
	"preview_target_overheat": "¡El rival se sobrecalentará!",
	"preview_backfire": "Te cuesta %d de vida",
	"preview_move": "Moverte a la casilla %d (distancia al rival: %d)",
	"preview_cool": "Enfriar: calor %d → %d",
	"illegal": "No disponible: %s",
	"log_weapon": "%s usa %s: %d de daño",
	"log_stomp": "%s pisotea: %d de daño",
	"log_drone": "El dron de %s dispara (%s): %d de daño",
	"log_charge": "%s embiste: %d de daño",
	"log_hook": "%s engancha al rival: %d de daño",
	"log_teleport": "%s salta a la casilla %d: %d de daño",
	"log_walk": "%s se mueve de %d a %d",
	"log_cool": "%s enfría %d de calor",
	"log_forced": "%s está sobrecalentado: enfría %d y solo tiene 1 acción",
	"log_shutdown": "¡%s se apaga! Enfría %d y pierde el turno",
	"log_win": "%s gana el combate",
	"victory": "VICTORIA",
	"defeat": "DERROTA",
	"rematch": "Revancha",
	"menu": "Menú",
	"menu_title": "MechForge",
	"menu_subtitle": "Combate de prueba contra la IA",
	"menu_player": "Tu mech",
	"menu_enemy": "Mech rival",
	"menu_tier": "Tier",
	"menu_difficulty": "Dificultad",
	"menu_fight": "Combatir",
	"difficulty_easy": "Fácil",
	"difficulty_normal": "Normal",
	"difficulty_hard": "Difícil",
	"thinking": "El rival piensa…",
}

const TIER_NAMES: Array[String] = ["Común", "Raro", "Épico", "Legendario", "Mítico", "Divino"]
const ELEMENT_NAMES: Array[String] = ["Físico", "Calor", "Energía", "Combinado"]


## Devuelve el texto de la clave, con los argumentos ya sustituidos.
static func t(key: String, args: Array = []) -> String:
	var text: String = ES.get(key, key)
	return text % args if not args.is_empty() else text
