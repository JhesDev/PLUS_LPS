import { createRouter, createWebHistory } from 'vue-router'
import { pathForRole } from '@/config/runtime'

/**
 * Rutas del boceto. Cada rol tiene su superficie; el guard redirige a la
 * vista del rol activo para no mezclar acciones de despacho con el modo
 * lectura del coordinador.
 */
export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/despacho' },
    {
      path: '/despacho',
      name: 'despacho',
      component: () => import('@/views/DispatcherView.vue'),
      meta: { title: 'Despacho', role: 'despachador' },
    },
    {
      path: '/coordinacion',
      name: 'coordinacion',
      component: () => import('@/views/CoordinatorView.vue'),
      meta: { title: 'Coordinación', role: 'coordinador' },
    },
    {
      path: '/tecnico',
      name: 'tecnico',
      component: () => import('@/views/TechnicianView.vue'),
      meta: { title: 'Mi jornada', role: 'tecnico' },
    },
    {
      path: '/:pathMatch(.*)*',
      name: 'no-encontrada',
      component: () => import('@/views/NotFoundView.vue'),
    },
  ],
  scrollBehavior: () => ({ top: 0 }),
})

/** Ajusta el título del documento según la ruta activa. */
router.afterEach((to) => {
  const title = typeof to.meta.title === 'string' ? to.meta.title : null
  document.title = title ? `${title} · PLUZ` : 'PLUZ · Panel operativo'
})

/** Permite navegar al rol activo sin hardcodear rutas en los componentes. */
export function roleHome(role: string): string {
  if (role === 'coordinador' || role === 'despachador' || role === 'tecnico') {
    return pathForRole(role)
  }
  return '/despacho'
}
