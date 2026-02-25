<script setup>
import VoltEditionSelector from './VoltEditionSelector.vue';

defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});
</script>

<template>
  <div class="px-4 py-2 text-n-slate-12">
    <VoltEditionSelector :conversation-id="conversationId" />
  </div>
</template>
