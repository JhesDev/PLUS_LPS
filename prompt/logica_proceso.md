El objetivo inmediato está clarísimo: diseñar e implementar la plataforma web central para la ingesta de datos desde SAP, la visualización en mapa interactivo de las órdenes (cortes, reposiciones, mantenimientos) y el flujo de asignación operativa a los técnicos de campo.

Para iniciar el análisis, la toma de decisiones de arquitectura UI/UX y la maquetación del boceto (wireframe), aquí tienes la lista de puntos clave y requerimientos funcionales y técnicos estructurada para esta fase web.



1. Módulo de Ingesta y Gestión de Datos (Backend / Sync)
Antes de pintar el mapa, la plataforma necesita recibir, estructurar y mantener sincronizada la base de datos local con la API B2B de PLUZ.

Estructura de Almacenamiento (PostGIS / DB):

Tablas de órdenes de trabajo con soporte espacial (Latitud/Longitud o geometrías Point).

Tablas de usuarios/cuadrillas (Técnicos, Despachadores, Coordinadores) vinculados a sus datos operativos.

Tablas de catálogo (Estados de orden, tipos de trabajo: corte, reposición, inspección, reconexión).

Frecuencia de Sincronización (CronJob / Worker):

Tarea programada para consultar la API de SAP en intervalos de tiempo fijos o botón de "Sincronizar ahora" en el panel.

Control de Duplicados y Actualizaciones:

Lógica para no sobrescribir órdenes que ya están en proceso por una cuadrilla si SAP vuelve a enviar el registro en el JSON.

2. Pantalla Principal: Visor de Mapa Interactivo (GIS Dashboard)
Es la vista técnica central donde el Despachador y el Coordinador pasan el 90% del tiempo.

Lienzo del Mapa Interactivo:

Proveedor de mapas limpio (como Mapbox, OpenStreetMap o Google Maps API con soporte de capas vectoriales).

Renderizado eficiente de cientos/miles de puntos (placemarks) usando Clustering (agrupación de puntos cercanos para no saturar la pantalla al hacer zoom alejado).

Simbología y Codificación Visual por Color/Icono:

Por Estado: Pendiente (Amarillo), Asignado (Azul), En Proceso (Naranja), Ejecutado (Verde), Imposibilitado/Rechazado (Rojo).

Por Tipo de Trabajo: Iconos diferenciados (p. ej., Tijeras para Corte, Enchufe/Rayo para Reposición, Herramienta para Mantenimiento).

Filtros Avanzados y Búsqueda Rápida:

Panel lateral o barra superior para filtrar por: Distrito/Zona, Cuadrante operativo, Estado de la orden, Rango de fechas/horas y Técnico asignado.

Buscador directo por Número de Suministro, Código de Orden o Nombre del Cliente.

Pop-up / Ficha Rápida al hacer clic en un Punto:

Al presionar un placemark, debe desplegar una tarjeta con: Nº de suministro, Dirección, Cliente, Tipo de trabajo, Criticidad y un botón directo de "Asignar".

3. Módulo de Asignación de Trabajo a Cuadrillas
El núcleo operativo de la plataforma web para repartir la carga a los técnicos.

Métodos de Asignación en Mapa:

Asignación Individual: Desde el cuadro emergente del punto en el mapa.

Asignación Masiva por Selección de Área (Lazo / Polígono): Herramienta que permita al despachador dibujar una figura geométrica en el mapa para encorralar 15 o 20 puntos de un solo golpe y asignárselos a un técnico específico.

Asignación por Proximidad (GPS de Cuadrilla): Capa opcional en el mapa que muestre la ubicación en tiempo real del técnico para ver qué punto le queda más cerca.

Manejo de Reasignaciones y Cancelaciones:

Opción para desasignar una orden si el técnico reporta una avería en su vehículo o redistribuir una ruta incompleta a otro trabajador.

4. Panel Lateral y Tablas de Trabajo (Data Tables)
No todo se resuelve en el mapa; se requiere una vista de tabla complementaria.

Vista Dividida (Mapa + Tabla):

Sincronización en dos vías: Seleccionar una fila en la tabla enfoca/hace zoom al punto en el mapa, y viceversa.

Métricas en Tiempo Real (Kpis rápidos arriba del panel):

Total de Órdenes del día, Órdenes Pendientes, En Ruta, Ejecutadas con éxito, Imposibilitadas.

5. Control de Acceso según los 3 Roles Definidos
Coordinador:

Acceso en Modo Lectura / Auditoría.

Puede ver el mapa, filtrar, revisar métricas y exportar reportes (Excel/PDF), pero no puede alterar asignaciones ni editar órdenes.

Despachador:

Acceso en Modo Operativo.

Control total para asignar, reasignar, crear rutas y gestionar los estados del trabajo en mapa.

Técnico (Web / Vista de consulta):

Aunque usará el aplicativo móvil, en la web puede contar con una vista simplificada para consultar su hoja de ruta diaria asignada.

📐 Sugerencia de Layout para el Boceto / Wireframe
Para la maquetación inicial, el diseño más limpio y funcional consta de 4 secciones principales:

Header (Barra Superior): Logo de Grupo LPS / PLUZ, contador de KPIs del día (Total, Pendientes, En curso, Finalizados), botón de sync manual con SAP y perfil de usuario con rol.

Barra Lateral Izquierda (Filtros y Lista de Órdenes): Pestañas para conmutar entre la lista de órdenes pendientes y la lista de cuadrillas/técnicos activos.

Área Central (Mapa Full-Screen): El visor principal con controles de zoom, capas, herramienta de selección por polígono y la leyenda de colores.

Modal / Drawer Desplegable (Detalle de Orden): Ventana deslizante desde la derecha al seleccionar un punto para ver fotos, datos completos del cliente y el historial de asignaciones.