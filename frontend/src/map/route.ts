/**
 * Secuencia de paradas de una ruta para dibujar en el mapa.
 *
 * Importante: son líneas rectas entre paradas ordenadas. No es geometría vial
 * ni el resultado de un motor de ruteo; el modelo de datos tampoco guarda
 * geometría de ruta (ver migración `0004_routes`).
 */
export interface RouteLine {
  coordinates: Array<[number, number]>
  label: string
}
