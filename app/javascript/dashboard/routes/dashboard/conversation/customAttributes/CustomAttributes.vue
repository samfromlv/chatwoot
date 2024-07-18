f
<template>
  <div class="custom-attributes--panel">
    <custom-attribute
      v-for="attribute in displayedAttributes"
      :key="attribute.id"
      :attribute-key="attribute.attribute_key"
      :attribute-type="attribute.attribute_display_type"
      :values="attribute.attribute_values"
      :label="attribute.attribute_display_name"
      :description="getAttributeDescription(attribute.attribute_description)"
      :value="attribute.value"
      :show-actions="true"
      :attribute-regex="attribute.regex_pattern"
      :regex-cue="attribute.regex_cue"
      :class="attributeClass"
      :contact-id="contactId"
      @update="onUpdate"
      @delete="onDelete"
      @copy="onCopy"
    />
    <p
      v-if="!displayedAttributes.length && emptyStateMessage"
      class="p-3 text-center"
    >
      {{ emptyStateMessage }}
    </p>
    <!-- Show more and show less buttons show it if the filteredAttributes length is greater than 5 -->
    <div v-if="filteredAttributes.length > 5" class="flex px-2 py-2">
      <woot-button
        size="small"
        :icon="showAllAttributes ? 'chevron-up' : 'chevron-down'"
        variant="clear"
        color-scheme="primary"
        class="!px-2 hover:!bg-transparent dark:hover:!bg-transparent"
        @click="onClickToggle"
      >
        {{ toggleButtonText }}
      </woot-button>
    </div>
  </div>
</template>

<script>
import CustomAttribute from 'dashboard/components/CustomAttribute.vue';
import alertMixin from 'shared/mixins/alertMixin';
import attributeMixin from 'dashboard/mixins/attributeMixin';
import uiSettingsMixin from 'dashboard/mixins/uiSettings';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

export default {
  components: {
    CustomAttribute,
  },
  mixins: [alertMixin, attributeMixin, uiSettingsMixin],
  props: {
    attributeType: {
      type: String,
      default: 'conversation_attribute',
    },
    tagFilter: {
      type: String,
      default: '',
    },
    attributeClass: {
      type: String,
      default: '',
    },
    contactId: { type: Number, default: null },
    attributeFrom: {
      type: String,
      required: true,
    },
    loadExpanded: {
      type: Boolean,
      default: false,
    },
    emptyStateMessage: {
      type: String,
      default: '',
    },
  },
  data() {
    return {
      showAllAttributes: this.loadExpanded,
    };
  },
  computed: {
    toggleButtonText() {
      return !this.showAllAttributes
        ? this.$t('CUSTOM_ATTRIBUTES.SHOW_MORE')
        : this.$t('CUSTOM_ATTRIBUTES.SHOW_LESS');
    },
    filteredAttributes() {
      let attr = this.attributes.map(attribute => {
        if (attribute.description_settings) return attribute;

        if (
          attribute.attribute_description &&
          attribute.attribute_description[0] === '{'
        ) {
          try {
            attribute.description_settings = JSON.parse(
              attribute.attribute_description
            );
          } catch (e) {
            attribute.description_settings = {};
          }
        } else {
          attribute.description_settings = {};
        }
        if (attribute.description_settings.sort_order === undefined) {
          attribute.description_settings.sort_order = 1000;
        }
        return attribute;
      });

      if (this.tagFilter) {
        attr = attr.filter(attribute => {
          return (
            attribute.description_settings.tags &&
            attribute.description_settings.tags.includes(this.tagFilter)
          );
        });
      }

      attr = attr.sort((a, b) => {
        if (
          a.description_settings.sort_order ===
          b.description_settings.sort_order
        ) {
          return a.attribute_display_name.localeCompare(
            b.attribute_display_name
          );
        }
        return a.sort_order - b.sort_order;
      });

      return attr.map(attribute => {
        // Check if the attribute key exists in customAttributes
        const hasValue = Object.hasOwnProperty.call(
          this.customAttributes,
          attribute.attribute_key
        );

        const isCheckbox = attribute.attribute_display_type === 'checkbox';
        const defaultValue = isCheckbox ? false : '';

        return {
          ...attribute,
          // Set value from customAttributes if it exists, otherwise use default value
          value: hasValue
            ? this.customAttributes[attribute.attribute_key]
            : defaultValue,
        };
      });
    },
    displayedAttributes() {
      // Show only the first 5 attributes or all depending on showAllAttributes
      if (this.showAllAttributes || this.filteredAttributes.length <= 5) {
        return this.filteredAttributes;
      }
      return this.filteredAttributes.slice(0, 5);
    },
    showMoreUISettingsKey() {
      return `show_all_attributes_${this.attributeFrom}`;
    },
  },
  mounted() {
    this.initializeSettings();
  },
  methods: {
    initializeSettings() {
      this.showAllAttributes =
        this.uiSettings[this.showMoreUISettingsKey] || false;
    },
    onClickToggle() {
      this.showAllAttributes = !this.showAllAttributes;
      this.updateUISettings({
        [this.showMoreUISettingsKey]: this.showAllAttributes,
      });
    },
    async onUpdate(key, value) {
      const updatedAttributes = { ...this.customAttributes, [key]: value };
      try {
        if (this.attributeType === 'conversation_attribute') {
          await this.$store.dispatch('updateCustomAttributes', {
            conversationId: this.conversationId,
            customAttributes: updatedAttributes,
          });
        } else {
          this.$store.dispatch('contacts/update', {
            id: this.contactId,
            custom_attributes: updatedAttributes,
          });
        }
        this.showAlert(this.$t('CUSTOM_ATTRIBUTES.FORM.UPDATE.SUCCESS'));
      } catch (error) {
        const errorMessage =
          error?.response?.message ||
          this.$t('CUSTOM_ATTRIBUTES.FORM.UPDATE.ERROR');
        this.showAlert(errorMessage);
      }
    },
    async onDelete(key) {
      try {
        const { [key]: remove, ...updatedAttributes } = this.customAttributes;
        if (this.attributeType === 'conversation_attribute') {
          await this.$store.dispatch('updateCustomAttributes', {
            conversationId: this.conversationId,
            customAttributes: updatedAttributes,
          });
        } else {
          this.$store.dispatch('contacts/deleteCustomAttributes', {
            id: this.contactId,
            customAttributes: [key],
          });
        }

        this.showAlert(this.$t('CUSTOM_ATTRIBUTES.FORM.DELETE.SUCCESS'));
      } catch (error) {
        const errorMessage =
          error?.response?.message ||
          this.$t('CUSTOM_ATTRIBUTES.FORM.DELETE.ERROR');
        this.showAlert(errorMessage);
      }
    },
    async onCopy(attributeValue) {
      await copyTextToClipboard(attributeValue);
      this.showAlert(this.$t('CUSTOM_ATTRIBUTES.COPY_SUCCESSFUL'));
    },
  },
};
</script>

<style scoped lang="scss">
.custom-attributes--panel {
  .conversation--attribute {
    @apply border-slate-50 dark:border-slate-700/50 border-b border-solid;
  }

  &.odd {
    .conversation--attribute {
      &:nth-child(2n + 1) {
        @apply bg-slate-25 dark:bg-slate-800/50;
      }
    }
  }

  &.even {
    .conversation--attribute {
      &:nth-child(2n) {
        @apply bg-slate-25 dark:bg-slate-800/50;
      }
    }
  }
}
</style>
