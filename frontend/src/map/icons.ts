import type { WorkOrderType } from '@/types/domain'

/**
 * Iconos de tipo de trabajo dibujados en canvas en tiempo de ejecución.
 *
 * Se generan localmente para no depender de un sprite externo ni de glifos de
 * un proveedor. El color lo aporta la capa de círculo por estado; el icono es
 * siempre blanco para contrastar sobre ese color.
 */

const SIZE = 24
const SCALE = 2

type Ctx = CanvasRenderingContext2D

function createContext(): { canvas: HTMLCanvasElement; ctx: Ctx } {
  const canvas = document.createElement('canvas')
  canvas.width = SIZE * SCALE
  canvas.height = SIZE * SCALE
  const ctx = canvas.getContext('2d')
  if (!ctx) throw new Error('No se pudo crear el contexto 2D del canvas.')
  ctx.scale(SCALE, SCALE)
  ctx.strokeStyle = '#ffffff'
  ctx.fillStyle = '#ffffff'
  ctx.lineWidth = 2
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'
  return { canvas, ctx }
}

function drawScissors(ctx: Ctx): void {
  ctx.beginPath()
  ctx.moveTo(7, 5)
  ctx.lineTo(17, 15)
  ctx.moveTo(17, 5)
  ctx.lineTo(7, 15)
  ctx.stroke()
  ctx.beginPath()
  ctx.arc(7, 18, 2.6, 0, Math.PI * 2)
  ctx.arc(17, 18, 2.6, 0, Math.PI * 2)
  ctx.stroke()
}

function drawBolt(ctx: Ctx): void {
  ctx.beginPath()
  ctx.moveTo(13, 3)
  ctx.lineTo(7, 13)
  ctx.lineTo(11.5, 13)
  ctx.lineTo(10, 21)
  ctx.lineTo(17, 10.5)
  ctx.lineTo(12.5, 10.5)
  ctx.closePath()
  ctx.fill()
}

function drawMagnifier(ctx: Ctx): void {
  ctx.beginPath()
  ctx.arc(11, 11, 5.4, 0, Math.PI * 2)
  ctx.stroke()
  ctx.beginPath()
  ctx.moveTo(15.2, 15.2)
  ctx.lineTo(20, 20)
  ctx.stroke()
}

function drawLink(ctx: Ctx): void {
  ctx.beginPath()
  ctx.arc(9, 12, 3.6, 0, Math.PI * 2)
  ctx.stroke()
  ctx.beginPath()
  ctx.arc(15, 12, 3.6, 0, Math.PI * 2)
  ctx.stroke()
}

function drawWrench(ctx: Ctx): void {
  ctx.beginPath()
  ctx.arc(8.5, 15.5, 3.2, 0, Math.PI * 2)
  ctx.stroke()
  ctx.beginPath()
  ctx.moveTo(11, 13)
  ctx.lineTo(19, 5)
  ctx.stroke()
  ctx.beginPath()
  ctx.moveTo(17.5, 3.5)
  ctx.lineTo(20.5, 6.5)
  ctx.stroke()
}

function drawDot(ctx: Ctx): void {
  ctx.beginPath()
  ctx.arc(12, 12, 3.4, 0, Math.PI * 2)
  ctx.fill()
}

const DRAWERS: Record<WorkOrderType, (ctx: Ctx) => void> = {
  corte: drawScissors,
  reposicion: drawBolt,
  inspeccion: drawMagnifier,
  reconexion: drawLink,
  mantenimiento: drawWrench,
  otro: drawDot,
}

export const TYPE_ICON_IDS: Record<WorkOrderType, string> = {
  corte: 'type-icon-corte',
  reposicion: 'type-icon-reposicion',
  inspeccion: 'type-icon-inspeccion',
  reconexion: 'type-icon-reconexion',
  mantenimiento: 'type-icon-mantenimiento',
  otro: 'type-icon-otro',
}

export interface RasterIcon {
  id: string
  width: number
  height: number
  data: Uint8ClampedArray
  pixelRatio: number
}

export function buildTypeIcons(): RasterIcon[] {
  return (Object.keys(DRAWERS) as WorkOrderType[]).map((type) => {
    const { canvas, ctx } = createContext()
    DRAWERS[type](ctx)
    const image = ctx.getImageData(0, 0, canvas.width, canvas.height)
    return {
      id: TYPE_ICON_IDS[type],
      width: canvas.width,
      height: canvas.height,
      data: image.data,
      pixelRatio: SCALE,
    }
  })
}

/** Marcador de cuadrilla: disco con anillo para distinguirlo de las órdenes. */
export function buildTechnicianIcon(): RasterIcon {
  const { canvas, ctx } = createContext()
  ctx.fillStyle = '#0a2540'
  ctx.beginPath()
  ctx.arc(12, 12, 7.5, 0, Math.PI * 2)
  ctx.fill()
  ctx.strokeStyle = '#ffffff'
  ctx.lineWidth = 2
  ctx.stroke()
  ctx.fillStyle = '#14a3a3'
  ctx.beginPath()
  ctx.arc(12, 12, 3.2, 0, Math.PI * 2)
  ctx.fill()
  const image = ctx.getImageData(0, 0, canvas.width, canvas.height)
  return {
    id: 'technician-marker',
    width: canvas.width,
    height: canvas.height,
    data: image.data,
    pixelRatio: SCALE,
  }
}
