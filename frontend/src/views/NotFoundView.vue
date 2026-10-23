<script setup lang="ts">
import { RouterLink } from 'vue-router'
import { roleHome } from '@/router'
import { useSessionStore } from '@/stores/session'

const session = useSessionStore()
</script>

<template>
  <div class="state-panel">
    <div class="state-panel__box">
      <p class="state-panel__title">Página no encontrada</p>
      <p class="state-panel__message">
        La ruta solicitada no existe en el boceto.
      </p>
      <RouterLink class="btn btn--primary" :to="session.role ? roleHome(session.role) : '/login'">
        Ir a mi vista
      </RouterLink>
    </div>
  </div>
</template>
