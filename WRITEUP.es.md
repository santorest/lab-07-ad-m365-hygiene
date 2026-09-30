---
title: "Kit de higiene de AD y Microsoft 365 (PowerShell)"
id: "lab-07-ad-m365-hygiene"
category: "Scripting y automatización"
type: "Laboratorio"
status: "completado"
date: "2026-09-30"
time_to_reproduce: "20–30 minutos (fork, activar Actions, ejecutar las pruebas)"
skills: [PowerShell, Active Directory, Microsoft Graph, Microsoft Entra ID, Microsoft 365, Pester, PSScriptAnalyzer, GitHub Actions]
frameworks: [CIS Controls v8 (5.1, 5.3, 6.1, 6.8), MITRE ATT&CK (T1558.003, T1558.004, T1078)]
repo: "https://github.com/santorest/lab-07-ad-m365-hygiene"
bundle: "Publicado en el sitio del portafolio con su checksum SHA-256"
---

# Kit de higiene de AD y Microsoft 365 (PowerShell)

> **En resumen:** un módulo de PowerShell de solo lectura que toma una instantánea de Active Directory y Microsoft
> 365 con el mínimo privilegio, ejecuta sobre ella doce controles de higiene (cuentas inactivas y expuestas a
> roasting, delegación sin restricciones, huecos de MFA, licencias sin uso, roles de administrador permanentes,
> invitados inactivos) y genera un informe HTML autocontenido. CI demuestra cada control en Windows PowerShell 5.1,
> PowerShell 7 en Windows y PowerShell 7 en Linux.
> **Las ejecuciones de CI son reales; las instantáneas son sintéticas.** El kit nunca se ha ejecutado contra un
> dominio o un tenant reales.

| | |
|---|---|
| **Rol** | Ingeniero de identidad / sistemas que construye una revisión de higiene repetible para AD y Microsoft 365 |
| **Entorno** | Repositorio público de GitHub, runners Windows y Ubuntu de GitHub |
| **Herramientas** | PowerShell 5.1 y 7, Pester 5.7.1, PSScriptAnalyzer 1.23.0, gitleaks |
| **Entregables** | Módulo con 12 controles, recolectores, salida HTML/CSV/JSON, informe de ejemplo, matriz de CI, ruleset, PR de demostración |

---

## 1. Problema

La higiene del directorio se degrada en silencio: cuentas que nadie usa, cuentas de servicio con SPN y contraseñas
que no caducan, grupos privilegiados que crecen, licencias en usuarios deshabilitados, administradores globales con
acceso permanente. La mayoría de los equipos lo revisa con scripts sueltos que requieren permisos de administrador,
escriben directamente en la consola y nunca se prueban. El objetivo: un kit que solo necesite acceso de lectura,
separe la recolección del análisis y tenga cada control demostrado en CI.

## 2. Diseño

- **Recolectar y después analizar.** `Get-HygieneAdSnapshot` y `Get-HygieneGraphSnapshot` son las únicas funciones
  que llaman a cmdlets de AD o de Graph. Construyen una instantánea de *conjuntos de datos*, cada uno
  `{status, error, items}`. La instantánea se puede guardar, mover y analizar más tarde, en cualquier lugar.
- **Controles puros.** Cada uno de los doce controles es una función sobre la instantánea y la configuración. Las
  antigüedades se cuentan desde el `collectedAt` de la instantánea, nunca desde el reloj, así que los resultados (y el
  informe de ejemplo) son reproducibles.
- **"No evaluado" en lugar de silencio.** Si los datos de un control no se recolectaron, o una llamada falló por
  permisos o licencias, el control devuelve un hallazgo que lo dice y explica por qué. Una licencia que falta nunca
  parece un tenant limpio.
- **Solo lectura por construcción.** Una prueba analiza el módulo y falla si aparece cualquier cmdlet de AD o de
  Graph que no sea `Get-*`, o un `Invoke-MgGraphRequest` directo.
- **Informe seguro.** Un único archivo HTML, CSS en línea, sin scripts ni recursos externos, cada valor codificado en
  HTML (los atributos del directorio los puede controlar un atacante) y enlaces tomados solo del catálogo de controles.

## 3. Controles

| Id | Control | Señala |
|---|---|---|
| AD-01 | Usuarios inactivos | Sin inicio de sesión en más de 90 días (o nunca, y creados hace más de 90 días) |
| AD-02 | Equipos inactivos | Sin inicio de sesión en más de 90 días |
| AD-03 | Contraseñas que no caducan | `PasswordNeverExpires` en usuarios habilitados |
| AD-04 | Pertenencia a grupos privilegiados | Miembros deshabilitados o inactivos (con la ruta de anidamiento); grupos con más de 5 miembros |
| AD-05 | Usuarios expuestos a Kerberoasting | Usuarios con SPN; alta si son privilegiados |
| AD-06 | Usuarios expuestos a AS-REP roasting | Preautenticación desactivada |
| AD-07 | Delegación sin restricciones | Equipos y usuarios, excluidos los controladores de dominio |
| M365-01 | Usuarios sin MFA | Miembros habilitados sin registro |
| M365-02 | Licencias sin uso | Puestos sin asignar; licencias en usuarios deshabilitados o inactivos |
| M365-03 | Número de administradores globales | Menos de 2 o más de 4 |
| M365-04 | Roles privilegiados permanentes | Asignaciones permanentes sin elegibilidad en PIM |
| M365-05 | Invitados inactivos | Invitaciones pendientes más de 30 días; sin inicio de sesión en más de 60 días |

## 4. Permisos

Active Directory: cualquier usuario autenticado del dominio (los atributos que se leen son legibles por defecto).
Microsoft Graph: `User.Read.All`, `AuditLog.Read.All`, `Directory.Read.All`, `RoleManagement.Read.Directory`. La
actividad de inicio de sesión requiere Microsoft Entra ID P1 y la elegibilidad de PIM requiere P2; sin ellas, los
controles afectados informan "no evaluado".

## 5. Pipeline

GitHub Actions ejecuta Pester 5.7.1 en tres entornos (Windows PowerShell 5.1, PowerShell 7 en Windows, PowerShell 7
en Linux), PSScriptAnalyzer 1.23.0 con cero hallazgos y gitleaks sobre todo el historial. Un ruleset de rama exige un
pull request y los cinco controles. Las pruebas cubren cada control con casos positivos y casi aciertos, los
recolectores con mocks (propiedades solicitadas, paginación, el caso de datos no disponibles), la guarda de solo
lectura, la codificación HTML y un informe de ejemplo que debe coincidir byte a byte con `docs/example-report.html`
en cada entorno.

## 6. Resultados

Los resultados se añaden a partir de las primeras ejecuciones de GitHub Actions (ver la tarea 13 del plan).

## 7. Lecciones

- **Windows PowerShell 5.1 es donde se esconden los errores.** Un resultado de un solo elemento se desenrolla en un
  objeto suelto, y el `PSCustomObject` de 5.1 no tiene `.Count`. Una prueba con una instantánea de un solo usuario lo
  detectó en la función auxiliar de las pruebas.
- **Los mocks de Pester 5 tienen sus propias reglas.** Los parámetros de una llamada simulada están en
  `$PesterBoundParameters`, no en `$PSBoundParameters`, y las llamadas hechas en un `BeforeAll` del archivo no las
  cuenta un `Should -Invoke` dentro de un `It`. Ambas cosas hicieron que código correcto de los recolectores pareciera
  roto hasta corregir las pruebas.
- **La codificación es una trampa de Windows PowerShell 5.1.** Sin BOM, 5.1 lee los archivos UTF-8 con la página de
  códigos local, así que el manifiesto (que contiene un nombre de autor con tilde) lleva BOM y PSScriptAnalyzer lo
  exige.
- **Las fechas cambian según el entorno.** `ConvertFrom-Json` de PowerShell 7 convierte las cadenas ISO en valores
  `DateTime`, mientras que 5.1 mantiene cadenas. Una sola función de conversión maneja ambos casos, y ejecutar cada
  prueba en los dos entornos lo demuestra.

## 8. Límites

- Nunca se ejecutó contra un dominio o tenant reales; no se afirman hallazgos sobre datos reales.
- `lastLogonTimestamp` se replica con un retraso de hasta unos 14 días, así que "inactivo" es aproximado por diseño.
- M365-04 es una heurística: un principal con una asignación permanente y otra elegible para el mismo rol no se señala.
- El recolector de Graph está modelado sobre los cmdlets del SDK Microsoft.Graph para PowerShell 2.x y se probó con
  stubs, no contra el SDK.

## 9. Cómo reproducirlo

1. Hacer fork del repositorio y activar GitHub Actions.
2. Aplicar `.github/rulesets/main.json` como ruleset de rama.
3. En local: `./scripts/Install-TestDependencies.ps1` y luego `./scripts/Invoke-Tests.ps1`.
4. Para auditar un entorno real (solo lectura): seguir el inicio rápido del README.

## 10. Correspondencia con marcos

- **CIS Controls v8:** 5.1 (inventario de cuentas), 5.3 (deshabilitar cuentas inactivas), 6.1/6.8 (concesión de
  acceso y acceso basado en roles).
- **MITRE ATT&CK:** T1558.003 (Kerberoasting), T1558.004 (AS-REP roasting), T1078 (cuentas válidas).
