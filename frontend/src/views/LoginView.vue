<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useSessionStore } from '@/stores/session'
import { roleHome } from '@/router'
import SourceBadge from '@/components/common/SourceBadge.vue'
import { DATA_MODE } from '@/config/dataSource'

const session = useSessionStore()
const router = useRouter()
const route = useRoute()

const email = ref('')
const password = ref('')
const submitting = ref(false)
const error = ref<string | null>(null)

const isDemo = computed(() => DATA_MODE === 'demo')

async function submit(): Promise<void> {
  error.value = null

  if (!email.value.trim() || !password.value) {
    error.value = 'Escribe tu correo y contraseña.'
    return
  }

  submitting.value = true
  try {
    await session.signIn({ email: email.value, password: password.value })
    const redirect =
      typeof route.query.redirect === 'string' ? route.query.redirect : null
    await router.replace(redirect ?? roleHome(session.role ?? 'tecnico'))
  } catch (caught) {
    error.value =
      caught instanceof Error ? caught.message : 'No se pudo iniciar sesión.'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="login-page">
    <section class="login-card">
      <header class="login-card__head">
        <span class="brand__logo" aria-hidden="true">LPS</span>
        <div>
          <h1 class="login-card__title">Grupo LPS · PLUZ</h1>
          <p class="text-sm muted">Panel operativo de campo</p>
        </div>
      </header>

      <template v-if="isDemo">
        <p class="alert alert--warning">
          Modo demostración: faltan <code class="mono">VITE_SUPABASE_URL</code> y
          <code class="mono">VITE_SUPABASE_PUBLISHABLE_KEY</code>. La aplicación
          funciona con datos ficticios del seed local y no se conecta a la base.
        </p>
        <RouterLink class="btn btn--primary btn--block" :to="roleHome(session.demoUser.role)">
          Entrar en modo demostración
        </RouterLink>
      </template>

      <form v-else class="stack" @submit.prevent="submit">
        <div class="field">
          <label for="login-email">Correo</label>
          <input
            id="login-email"
            v-model="email"
            class="input"
            type="email"
            autocomplete="username"
            required
            placeholder="usuario@plus-lps.test"
          />
        </div>

        <div class="field">
          <label for="login-password">Contraseña</label>
          <input
            id="login-password"
            v-model="password"
            class="input"
            type="password"
            autocomplete="current-password"
            required
          />
        </div>

        <p v-if="error" class="alert alert--error" role="alert">{{ error }}</p>

        <button type="submit" class="btn btn--primary btn--block" :disabled="submitting">
          {{ submitting ? 'Ingresando…' : 'Ingresar' }}
        </button>

        <p class="text-xs muted center">
          El rol se lee de <code class="mono">public.profiles</code>; no se puede
          elegir desde la interfaz.
        </p>
      </form>

      <footer class="login-card__foot">
        <SourceBadge compact />
        <span class="text-xs muted">
          {{ isDemo ? 'Sin conexión a Supabase.' : 'Sesión de Supabase Auth.' }}
        </span>
      </footer>
    </section>
  </div>
</template>

<style scoped>
.login-page {
  display: grid;
  place-items: center;
  min-height: 100%;
  padding: 24px;
}

.login-card {
  width: 100%;
  max-width: 400px;
  background: var(--surface);
  border: 1px solid var(--ink-200);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow);
  padding: 22px;
  display: grid;
  gap: 16px;
}

.login-card__head {
  display: flex;
  align-items: center;
  gap: 12px;
}

.login-card__title {
  font-size: 17px;
  font-weight: 800;
}

.login-card__foot {
  display: flex;
  align-items: center;
  gap: 8px;
  border-top: 1px solid var(--ink-200);
  padding-top: 12px;
}
</style>
