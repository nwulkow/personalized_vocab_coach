<template>
  <section class="legacy-placeholder" aria-live="polite">
    <h3>Chat window moved</h3>
    <p>This component is no longer used in the current UI.</p>
  </section>
</template>

<script>
export default {
  name: 'ChatWindow'
}
</script>

<style scoped>
.legacy-placeholder {
  padding: 1rem;
  border: 1px dashed #c8c8c8;
  border-radius: 8px;
  color: #666;
  background: #fafafa;
}
h3 {
  margin: 0 0 0.4rem;
  font-size: 1rem;
}
p {
  margin: 0;
  font-size: 0.9rem;
}
</style>
