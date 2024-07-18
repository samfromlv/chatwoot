<!-- eslint-disable vue/no-mutating-props -->
<template>
  <woot-modal
    :show.sync="show"
    :on-close="onCancel"
    size="medium"
    overflow-visible="true"
  >
    <div class="flex flex-col modal-content">
      <woot-modal-header
        :header-title="$t('CONVERSATION.RESOLVE_CONVERSATION.TITLE')"
        :header-content="$t('CONVERSATION.RESOLVE_CONVERSATION.DESC')"
      />
      <div class="flex-row p-4 mb-16">
        <conversation-info
          :conversation-attributes="conversationAdditionalAttributes"
          attribute-from="resolve_conversation"
          tag-filter="required_to_resolve"
          :load-expanded="true"
          :contact-attributes="contactAdditionalAttributes"
        />
      </div>
      <div class="flex-row px-8">
        <label :class="{ error: $v.requiredAttributes.$error }">
          <span v-if="$v.requiredAttributes.$error" class="message">
            {{
              $t('CONVERSATION.RESOLVE_CONVERSATION.FORM.VALIDATION_MESSAGE')
            }}
          </span>
        </label>
      </div>
      <div class="flex flex-row justify-end gap-2 py-4 px-8 w-full">
        <woot-button :is-loading="isLoading" @click.prevent="onFormSubmit">
          {{ $t('CONVERSATION.RESOLVE_CONVERSATION.FORM.SUBMIT') }}
        </woot-button>
        <button class="button clear" @click.prevent="onCancel">
          {{ $t('CONVERSATION.RESOLVE_CONVERSATION.FORM.CANCEL') }}
        </button>
      </div>
    </div>
  </woot-modal>
</template>

<script>
import { mapGetters } from 'vuex';
import ConversationInfo from './ConversationInfo.vue';
import attributeMixin from 'dashboard/mixins/attributeMixin';

export default {
  components: {
    ConversationInfo,
  },
  mixins: [attributeMixin],
  props: {
    isLoading: {
      type: Boolean,
      default: false,
    },
    show: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      attributeType: 'conversation_attribute',
      requiredAttributes: [],
    };
  },
  validations: {
    requiredAttributes: {
      isValid(value) {
        // check if any attribute is empty and show error
        return value.filter(x => !x.hasValue).length === 0;
      },
    },
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      currentUser: 'getCurrentUser',
      uiFlags: 'inboxAssignableAgents/getUIFlags',
    }),
    conversationAdditionalAttributes() {
      return this.filterObjectKeys(
        this.$store.getters['conversationMetadata/getConversationMetadata'](
          this.conversationId
        )?.additional_attributes || {},
        '_crqa'
      );
    },
    editedAttributes() {
      var attr = this.attributes;

      return attr
        .map(attribute => {
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
          return attribute;
        })
        .filter(
          x =>
            x.description_settings &&
            x.description_settings.tags &&
            x.description_settings.tags.includes('required_to_resolve')
        )
        .map(attribute => {
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

            hasValue: hasValue,
          };
        });
    },
    contact() {
      return this.$store.getters['contacts/getContact'](this.contactId);
    },
    contactAdditionalAttributes() {
      return this.contact.additional_attributes || {};
    },
    contactId() {
      return this.currentChat.meta?.sender?.id;
    },
  },
  methods: {
    onFormSubmit() {
      this.requiredAttributes = this.editedAttributes;
      this.$v.$touch();
      if (this.$v.requiredAttributes.$invalid) {
        return;
      }
      this.$emit('resolve');
    },
    filterObjectKeys(obj, text) {
      return Object.keys(obj).reduce((filteredObj, key) => {
        if (key.includes(text)) {
          filteredObj[key] = obj[key];
        }
        return filteredObj;
      }, {});
    },
    onCancel() {
      this.$emit('cancel');
    },
    onSuccess() {
      this.$emit('cancel');
    },
  },
};
</script>
