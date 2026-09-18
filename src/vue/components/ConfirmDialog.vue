<script setup lang="ts">

defineProps<{
  visible: boolean;
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
}>();

const emit = defineEmits<{
  'update:visible': [value: boolean];
  confirm: [];
  cancel: [];
}>();

function handleConfirm() {
  emit('update:visible', false);
  emit('confirm');
}
function handleCancel() {
  emit('update:visible', false);
  emit('cancel');
}
</script>

<template>
  <Dialog
    :visible="visible"
    :modal="true"
    :closable="false"
    :style="{ width: '440px' }"
    :pt="{ root: { style: 'border: 2px solid #ef4444;' } }"
  >
    <template #header>
      <div class="flex items-center gap-3">
        <span style="font-size: 1.4rem; line-height: 1;">⚠</span>
        <span class="font-semibold text-base">{{ title }}</span>
      </div>
    </template>
    <p class="text-sm text-gray-700 m-0">{{ message }}</p>
    <template #footer>
      <div class="flex justify-end gap-3">
        <PButton :label="cancelLabel ?? 'No, go back'" severity="danger" @click="handleCancel" />
        <PButton :label="confirmLabel ?? 'Yes, next'" severity="success" @click="handleConfirm" />
      </div>
    </template>
  </Dialog>
</template>