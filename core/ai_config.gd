class_name AIConfig
extends Resource
## Parametros de la funcion de valoracion de la IA (GDD 7). La valoracion se
## mide en fracciones de barra de vida. El valor de una accion no es fijo: es
## el dano medio que hace una accion de ese mech sobre la vida del rival.

## Cuanto vale el calor acumulado frente a una accion ya perdida. Cada
## `enfriamiento` de calor acabara costando una accion, salvo que el combate
## termine antes; por eso vale menos que 1.
@export var heat_discount: float = 0.6
## Cuanto vale dejar a un mech sin energia para sus armas (un turno entero
## sin disparar valdria 1).
@export var energy_discount: float = 0.7
## Cuanto cuesta quedar a una distancia desde la que las armas no alcanzan
## (acercarse cuesta una accion; 1 seria la accion entera).
@export var position_discount: float = 0.5
## Valor de ganar o perder el combate.
@export var win_value: float = 100.0

@export_group("Dificultad")
## Ruido uniforme (+-) que se suma a cada valoracion en dificultad facil.
@export var easy_noise: float = 0.20
## En dificil, cuantas de las mejores jugadas se revisan contra la mejor
## respuesta del rival.
@export var hard_candidates: int = 6
