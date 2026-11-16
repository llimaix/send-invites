# Plantilla de WhatsApp: `recordatorio_fiesta_60`

> Estado: **borrador**, no enviado a aprobación de Meta. Hay que resolver los pendientes del final antes de cargarla.

Datos del evento tomados de `rodolfo-invite/frontend/src/config/event.js`. La ruta de RSVP (`/confirmar`) sale de `rodolfo-invite/frontend/src/App.jsx`.

## Definición

| Campo | Valor |
|---|---|
| Nombre | `recordatorio_fiesta_60` |
| Categoría | Marketing (Meta decide la categoría final al revisarla) |
| Idioma | Español (`es`) |
| Encabezado (texto) | `Celebración de 60 años` (sin emojis; Meta no los permite en el encabezado) |
| Pie | `Si no deseas más mensajes, responde NO` |
| Botón URL 1 | `Confirmar asistencia` → `https://<dominio>/confirmar` |
| Botón URL 2 | `Escribirme` → `https://wa.me/502XXXXXXXX` (número personal de Luis) |

### Cuerpo

```
Hola {{1}}, te recordamos con mucho cariño que contamos con tu presencia en la celebración de los 60 años de Rodolfo.

📅 Sábado 26 de diciembre de 2026
🕟 4:30 p. m.
📍 Turicentro El Paraíso, 9a Calle, Zona 5, Villa Nueva

Tu invitación es para {{2}} persona(s).

Si aún no has confirmado en el sitio, hazlo con el botón "Confirmar asistencia" usando el número de teléfono donde recibes este mensaje.

Este número solo envía recordatorios; para cualquier duda, usa el botón "Escribirme".
```

### Variables

| Variable | Origen (Google Sheet) | Ejemplo para la revisión de Meta |
|---|---|---|
| `{{1}}` | `nombre` | `María` |
| `{{2}}` | `invitados` (cupo) | `2` |

## Por qué está redactada así

- **`{{1}}` después de "Hola":** Meta rechaza plantillas con variables al inicio o al final del cuerpo.
- **`{{2}}` es el cupo:** el invitado sabe cuántos lugares tiene antes de confirmar. Si no se quiere, se quita y la plantilla queda con una sola variable.
- **"Usando el número de teléfono donde recibes este mensaje":** el RSVP valida contra la lista de invitados por número (últimos 8 dígitos). Si confirman con otro número, el sitio los rechaza.
- **"Si aún no has confirmado en el sitio":** el flujo ya excluye a quien tiene RSVP, pero alguien pudo haber confirmado solo por WhatsApp personal. La frase no suena a reclamo.
- **Pie con "responde NO":** da una salida antes que bloquear el número, y los bloqueos bajan la calificación de calidad.
- **Redacción neutra en género:** "contamos con tu presencia" en vez de "estás invitado/a".

## Pendientes antes de enviarla a aprobación

- [ ] **Nombre del festejado:** `event.js` dice `Edvin Vásquez`, pero el proyecto y la galería usan Rodolfo (commit `f97a5b0` de `rodolfo-invite`). Hay que confirmar el nombre correcto y que la plantilla y el sitio coincidan.
- [ ] **Dominio** del sitio para el botón 1. No está versionado porque está en `terraform.tfvars`.
- [ ] **Número personal** para el botón 2.
- [ ] **Verificar** que Meta acepte `wa.me` en un botón de URL.
- [ ] **Verificar** si la plantilla se puede enviar a revisión antes de registrar el número real (chip).
