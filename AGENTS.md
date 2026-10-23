# AGENTS.md — Reglas globales del proyecto

## 1. Objetivo
Trabajar sobre el código existente con cambios pequeños, verificables, seguros y coherentes con la arquitectura real del proyecto.

## 2. Inspección obligatoria
Antes de modificar archivos:
- Inspeccionar la estructura de directorios y los archivos relevantes.
- Leer las instrucciones existentes, README, configuración y dependencias.
- Identificar las tecnologías y versiones reales.
- Revisar el flujo de ejecución y las dependencias entre componentes.
- Buscar implementaciones existentes antes de crear otras nuevas.
- No asumir rutas, tablas, endpoints, funciones, variables de entorno ni esquemas que no se hayan verificado.

No volver a analizar todo el repositorio si el contexto y los cambios anteriores siguen siendo suficientes. Concentrarse en los archivos afectados y sus dependencias.

## 3. Arquitectura y responsabilidades
- Backend: API, lógica de negocio, validaciones del servidor, integración con servicios y tareas asíncronas.
- Frontend: interfaz, componentes, navegación, estado y consumo de la API.
- DB Manager: esquema PostgreSQL, SQL, migraciones, restricciones, índices, funciones, vistas, triggers y RLS.
- Cada agente debe respetar la propiedad de archivos y responsabilidades de los demás.
- Los cambios que afecten contratos API, tablas, columnas, funciones RPC o estructuras JSON deben comunicarse a los agentes afectados.
- No duplicar lógica de negocio en el frontend cuando corresponda al backend.

## 4. Fuente de verdad
- El código y la configuración existentes son la referencia inicial.
- Las migraciones versionadas son la fuente de verdad de los cambios del esquema.
- Los contratos reales de la API son la fuente de verdad para las integraciones.
- No crear soluciones paralelas cuando ya existe un mecanismo equivalente.
- Si la documentación contradice el código, identificar la discrepancia antes de modificarlo.

## 5. Calidad del código
- Seguir los patrones, convenciones y arquitectura existentes.
- Priorizar legibilidad, mantenibilidad, tipado y separación de responsabilidades.
- Evitar duplicación, complejidad innecesaria, dependencias nuevas injustificadas y abstracciones prematuras.
- No reescribir módulos completos para resolver un problema localizado.
- Mantener compatibilidad con las funciones existentes, salvo que el requerimiento autorice un cambio incompatible.

## 6. Seguridad
- Nunca mostrar, registrar ni copiar secretos, contraseñas, tokens o claves privadas.
- No modificar credenciales ni archivos de entorno reales.
- Validar entradas y aplicar permisos en el servidor.
- No desactivar autenticación, autorización o RLS para hacer funcionar una implementación.
- No ejecutar operaciones destructivas, despliegues ni cambios remotos sin autorización explícita.

## 7. Ejecución y pruebas
- Ejecutar las pruebas pertinentes disponibles en el proyecto.
- Añadir pruebas para la lógica nueva y los errores previsibles.
- No afirmar que una prueba pasó si no se ejecutó.
- Si una prueba no puede ejecutarse, explicar por qué y qué falta.
- No ocultar errores ni convertir fallos en éxitos silenciosos.
- No realizar cambios ajenos al requerimiento.

## 8. Coordinación entre agentes
Antes de una modificación que afecte a otro módulo:
1. Identificar el contrato o recurso compartido.
2. Indicar qué debe cambiar y por qué.
3. Proponer el contrato esperado antes de implementarlo.
4. Verificar la compatibilidad una vez integrados los cambios.

No asumir que los otros agentes conocen automáticamente esta conversación o los cambios realizados fuera de su sesión.

## 9. Git y archivos compartidos
- Revisar git status antes de editar.
- No sobrescribir cambios previos del usuario.
- No ejecutar git reset, git clean, checkout destructivo ni revertir cambios ajenos sin autorización.
- Evitar que varios agentes modifiquen simultáneamente el mismo archivo.
- No crear commits ni hacer push sin autorización.

## 10. Informe de entrega
Al finalizar, informar:
- Qué se modificó.
- Qué archivos se tocaron.
- Qué decisiones técnicas se tomaron.
- Qué pruebas se ejecutaron y sus resultados.
- Qué riesgos o limitaciones permanecen.
- Qué debe saber o hacer otro agente para continuar.

No afirmar que el trabajo está terminado si faltan pasos esenciales.