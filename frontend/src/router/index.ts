import { createRouter, createWebHistory } from 'vue-router'
import { pathForRole } from '@/config/runtime'
import { useSessionStore } from '@/stores/session'
import type { AppRole } from '@/types/domain'

/**
 * Rutas del boceto alpha.
 *
 * Cada rol tiene su superficie. El guard redirige a `/login` cuando no hay
 * sesión y a la vista propia del rol cuando intenta entrar en otra. Es una
 * protección de experiencia: la autorización real la aplican RLS y el backend.
 */
export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/despacho' },
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/LoginView.vue'),
      meta: { title: 'Ingresar', public: true },
    },
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
      meta: { public: true },
    },
  ],
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach(async (to) => {
  const session = useSessionStore()

  // Restauración de sesión la primera vez que se navega.
  if (session.status === 'loading') {
    await session.init()
    session.subscribe()
  }

  const isPublic = to.meta.public === true

  if (!session.isReady) {
    if (isPublic) return true
    return { name: 'login', query: to.fullPath === '/' ? {} : { redirect: to.fullPath } }
  }

  if (to.name === 'login') {
    return pathForRole(session.role as AppRole)
  }

  const required = to.meta.role as AppRole | undefined
  if (required && session.role !== required) {
    return pathForRole(session.role as AppRole)
  }

  return true
})

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
