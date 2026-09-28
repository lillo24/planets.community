export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      notification_categories: {
        Row: {
          default_in_app_enabled: boolean
          default_push_enabled: boolean
          slug: string
          sort_order: number
          user_configurable: boolean
        }
        Insert: {
          default_in_app_enabled: boolean
          default_push_enabled: boolean
          slug: string
          sort_order: number
          user_configurable?: boolean
        }
        Update: {
          default_in_app_enabled?: boolean
          default_push_enabled?: boolean
          slug?: string
          sort_order?: number
          user_configurable?: boolean
        }
        Relationships: []
      }
      notifications: {
        Row: {
          actor_profile_id: string | null
          category_slug: string
          chat_id: string | null
          created_at: string
          destination_kind: string
          id: string
          membership_id: string | null
          message_id: string | null
          notification_kind: string
          project_id: string | null
          read_at: string | null
          recipient_profile_id: string
          request_id: string | null
          resource_agreement_event_id: string | null
          resource_agreement_id: string | null
          resource_chat_id: string | null
          resource_chat_message_id: string | null
          resource_listing_id: string | null
          resource_request_id: string | null
          source_outbox_event_id: string
        }
        Insert: {
          actor_profile_id?: string | null
          category_slug: string
          chat_id?: string | null
          created_at: string
          destination_kind: string
          id?: string
          membership_id?: string | null
          message_id?: string | null
          notification_kind: string
          project_id?: string | null
          read_at?: string | null
          recipient_profile_id: string
          request_id?: string | null
          resource_agreement_event_id?: string | null
          resource_agreement_id?: string | null
          resource_chat_id?: string | null
          resource_chat_message_id?: string | null
          resource_listing_id?: string | null
          resource_request_id?: string | null
          source_outbox_event_id: string
        }
        Update: {
          actor_profile_id?: string | null
          category_slug?: string
          chat_id?: string | null
          created_at?: string
          destination_kind?: string
          id?: string
          membership_id?: string | null
          message_id?: string | null
          notification_kind?: string
          project_id?: string | null
          read_at?: string | null
          recipient_profile_id?: string
          request_id?: string | null
          resource_agreement_event_id?: string | null
          resource_agreement_id?: string | null
          resource_chat_id?: string | null
          resource_chat_message_id?: string | null
          resource_listing_id?: string | null
          resource_request_id?: string | null
          source_outbox_event_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_actor_profile_id_fkey"
            columns: ["actor_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_category_slug_fkey"
            columns: ["category_slug"]
            isOneToOne: false
            referencedRelation: "notification_categories"
            referencedColumns: ["slug"]
          },
          {
            foreignKeyName: "notifications_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "project_group_chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_membership_id_fkey"
            columns: ["membership_id"]
            isOneToOne: false
            referencedRelation: "project_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "project_chat_messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_recipient_profile_id_fkey"
            columns: ["recipient_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_request_id_fkey"
            columns: ["request_id"]
            isOneToOne: false
            referencedRelation: "project_join_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_resource_agreement_event_id_fkey"
            columns: ["resource_agreement_event_id"]
            isOneToOne: false
            referencedRelation: "resource_exchange_agreement_events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_resource_agreement_id_fkey"
            columns: ["resource_agreement_id"]
            isOneToOne: false
            referencedRelation: "resource_exchange_agreements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_resource_chat_id_fkey"
            columns: ["resource_chat_id"]
            isOneToOne: false
            referencedRelation: "resource_request_chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_resource_chat_message_id_fkey"
            columns: ["resource_chat_message_id"]
            isOneToOne: false
            referencedRelation: "resource_request_chat_messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_resource_listing_id_fkey"
            columns: ["resource_listing_id"]
            isOneToOne: false
            referencedRelation: "resource_listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_resource_request_id_fkey"
            columns: ["resource_request_id"]
            isOneToOne: false
            referencedRelation: "resource_listing_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      profile_field_visibility: {
        Row: {
          audience: string
          field_key: string
          profile_id: string
        }
        Insert: {
          audience?: string
          field_key: string
          profile_id: string
        }
        Update: {
          audience?: string
          field_key?: string
          profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "profile_field_visibility_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profile_notification_preferences: {
        Row: {
          category_slug: string
          created_at: string
          in_app_enabled: boolean
          profile_id: string
          push_enabled: boolean
          updated_at: string
        }
        Insert: {
          category_slug: string
          created_at?: string
          in_app_enabled: boolean
          profile_id: string
          push_enabled: boolean
          updated_at?: string
        }
        Update: {
          category_slug?: string
          created_at?: string
          in_app_enabled?: boolean
          profile_id?: string
          push_enabled?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "profile_notification_preferences_category_slug_fkey"
            columns: ["category_slug"]
            isOneToOne: false
            referencedRelation: "notification_categories"
            referencedColumns: ["slug"]
          },
          {
            foreignKeyName: "profile_notification_preferences_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profile_photos: {
        Row: {
          audience: string
          created_at: string
          object_path: string
          profile_id: string
          updated_at: string
        }
        Insert: {
          audience?: string
          created_at?: string
          object_path: string
          profile_id: string
          updated_at?: string
        }
        Update: {
          audience?: string
          created_at?: string
          object_path?: string
          profile_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "profile_photos_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profile_skills: {
        Row: {
          created_at: string
          profile_id: string
          skill_id: string
        }
        Insert: {
          created_at?: string
          profile_id: string
          skill_id: string
        }
        Update: {
          created_at?: string
          profile_id?: string
          skill_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "profile_skills_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profile_skills_skill_id_fkey"
            columns: ["skill_id"]
            isOneToOne: false
            referencedRelation: "skills"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          bio: string | null
          created_at: string
          display_name: string | null
          id: string
          updated_at: string
        }
        Insert: {
          bio?: string | null
          created_at?: string
          display_name?: string | null
          id: string
          updated_at?: string
        }
        Update: {
          bio?: string | null
          created_at?: string
          display_name?: string | null
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      project_chat_messages: {
        Row: {
          body: string
          chat_id: string
          created_at: string
          id: string
          sender_profile_id: string
        }
        Insert: {
          body: string
          chat_id: string
          created_at?: string
          id?: string
          sender_profile_id: string
        }
        Update: {
          body?: string
          chat_id?: string
          created_at?: string
          id?: string
          sender_profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_chat_messages_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "project_group_chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_chat_messages_sender_profile_id_fkey"
            columns: ["sender_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      project_chat_requirement_attention_receipts: {
        Row: {
          acknowledged_through_created_at: string
          acknowledged_through_event_id: string
          chat_id: string
          profile_id: string
          updated_at: string
        }
        Insert: {
          acknowledged_through_created_at: string
          acknowledged_through_event_id: string
          chat_id: string
          profile_id: string
          updated_at?: string
        }
        Update: {
          acknowledged_through_created_at?: string
          acknowledged_through_event_id?: string
          chat_id?: string
          profile_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_chat_requirement_attention_receipts_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "project_group_chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_chat_requirement_attention_receipts_event_cursor_fkey"
            columns: [
              "chat_id",
              "acknowledged_through_created_at",
              "acknowledged_through_event_id",
            ]
            isOneToOne: false
            referencedRelation: "project_chat_system_events"
            referencedColumns: ["chat_id", "created_at", "id"]
          },
          {
            foreignKeyName: "project_chat_requirement_attention_receipts_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      project_chat_system_events: {
        Row: {
          chat_id: string
          created_at: string
          event_kind: string
          id: string
          requirement_kind: string
          resource_need_id: string | null
          skill_id: string | null
          source_outbox_event_id: string
        }
        Insert: {
          chat_id: string
          created_at: string
          event_kind: string
          id?: string
          requirement_kind: string
          resource_need_id?: string | null
          skill_id?: string | null
          source_outbox_event_id: string
        }
        Update: {
          chat_id?: string
          created_at?: string
          event_kind?: string
          id?: string
          requirement_kind?: string
          resource_need_id?: string | null
          skill_id?: string | null
          source_outbox_event_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_chat_system_events_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "project_group_chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_chat_system_events_resource_need_id_fkey"
            columns: ["resource_need_id"]
            isOneToOne: false
            referencedRelation: "project_resource_needs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_chat_system_events_skill_id_fkey"
            columns: ["skill_id"]
            isOneToOne: false
            referencedRelation: "skills"
            referencedColumns: ["id"]
          },
        ]
      }
      project_group_chats: {
        Row: {
          activated_at: string
          created_at: string
          id: string
          project_id: string
        }
        Insert: {
          activated_at: string
          created_at?: string
          id?: string
          project_id: string
        }
        Update: {
          activated_at?: string
          created_at?: string
          id?: string
          project_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_group_chats_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: true
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      project_join_request_resource_acceptance_decisions: {
        Row: {
          decided_at: string
          decided_by_profile_id: string
          disposition: string
          request_id: string
          resource_need_id: string
        }
        Insert: {
          decided_at: string
          decided_by_profile_id: string
          disposition: string
          request_id: string
          resource_need_id: string
        }
        Update: {
          decided_at?: string
          decided_by_profile_id?: string
          disposition?: string
          request_id?: string
          resource_need_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_join_request_resource_acceptance_decided_by_fkey"
            columns: ["decided_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_join_request_resource_acceptance_selection_fkey"
            columns: ["request_id", "resource_need_id"]
            isOneToOne: true
            referencedRelation: "project_join_request_resource_selections"
            referencedColumns: ["request_id", "resource_need_id"]
          },
        ]
      }
      project_join_request_resource_selections: {
        Row: {
          request_id: string
          resource_need_id: string
          selected_at: string
        }
        Insert: {
          request_id: string
          resource_need_id: string
          selected_at?: string
        }
        Update: {
          request_id?: string
          resource_need_id?: string
          selected_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_join_request_resource_selections_need_id_fkey"
            columns: ["resource_need_id"]
            isOneToOne: false
            referencedRelation: "project_resource_needs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_join_request_resource_selections_request_id_fkey"
            columns: ["request_id"]
            isOneToOne: false
            referencedRelation: "project_join_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      project_join_request_skill_acceptance_decisions: {
        Row: {
          decided_at: string
          decided_by_profile_id: string
          disposition: string
          request_id: string
          skill_id: string
        }
        Insert: {
          decided_at: string
          decided_by_profile_id: string
          disposition: string
          request_id: string
          skill_id: string
        }
        Update: {
          decided_at?: string
          decided_by_profile_id?: string
          disposition?: string
          request_id?: string
          skill_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_join_request_skill_acceptance_decided_by_fkey"
            columns: ["decided_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_join_request_skill_acceptance_selection_fkey"
            columns: ["request_id", "skill_id"]
            isOneToOne: true
            referencedRelation: "project_join_request_skill_selections"
            referencedColumns: ["request_id", "skill_id"]
          },
        ]
      }
      project_join_request_skill_selections: {
        Row: {
          request_id: string
          selected_at: string
          skill_id: string
        }
        Insert: {
          request_id: string
          selected_at?: string
          skill_id: string
        }
        Update: {
          request_id?: string
          selected_at?: string
          skill_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_join_request_skill_selections_request_id_fkey"
            columns: ["request_id"]
            isOneToOne: false
            referencedRelation: "project_join_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_join_request_skill_selections_skill_id_fkey"
            columns: ["skill_id"]
            isOneToOne: false
            referencedRelation: "skills"
            referencedColumns: ["id"]
          },
        ]
      }
      project_join_requests: {
        Row: {
          created_at: string
          id: string
          project_id: string
          request_message: string | null
          requester_profile_id: string
          resolved_at: string | null
          resolved_by_profile_id: string | null
          status: string
        }
        Insert: {
          created_at?: string
          id?: string
          project_id: string
          request_message?: string | null
          requester_profile_id: string
          resolved_at?: string | null
          resolved_by_profile_id?: string | null
          status?: string
        }
        Update: {
          created_at?: string
          id?: string
          project_id?: string
          request_message?: string | null
          requester_profile_id?: string
          resolved_at?: string | null
          resolved_by_profile_id?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_join_requests_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_join_requests_requester_profile_id_fkey"
            columns: ["requester_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_join_requests_resolved_by_profile_id_fkey"
            columns: ["resolved_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      project_manual_resource_coverages: {
        Row: {
          marked_at: string
          marked_by_profile_id: string
          originating_request_id: string | null
          resource_need_id: string
        }
        Insert: {
          marked_at?: string
          marked_by_profile_id: string
          originating_request_id?: string | null
          resource_need_id: string
        }
        Update: {
          marked_at?: string
          marked_by_profile_id?: string
          originating_request_id?: string | null
          resource_need_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_manual_resource_coverages_marked_by_fkey"
            columns: ["marked_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_manual_resource_coverages_need_id_fkey"
            columns: ["resource_need_id"]
            isOneToOne: true
            referencedRelation: "project_resource_needs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_manual_resource_coverages_request_id_fkey"
            columns: ["originating_request_id"]
            isOneToOne: false
            referencedRelation: "project_join_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      project_manual_skill_coverages: {
        Row: {
          marked_at: string
          marked_by_profile_id: string
          originating_request_id: string | null
          project_id: string
          skill_id: string
        }
        Insert: {
          marked_at?: string
          marked_by_profile_id: string
          originating_request_id?: string | null
          project_id: string
          skill_id: string
        }
        Update: {
          marked_at?: string
          marked_by_profile_id?: string
          originating_request_id?: string | null
          project_id?: string
          skill_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_manual_skill_coverages_marked_by_fkey"
            columns: ["marked_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_manual_skill_coverages_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_manual_skill_coverages_request_id_fkey"
            columns: ["originating_request_id"]
            isOneToOne: false
            referencedRelation: "project_join_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_manual_skill_coverages_skill_id_fkey"
            columns: ["skill_id"]
            isOneToOne: false
            referencedRelation: "skills"
            referencedColumns: ["id"]
          },
        ]
      }
      project_membership_actual_effort_markers: {
        Row: {
          marked_at: string
          marked_by_profile_id: string
          membership_id: string
        }
        Insert: {
          marked_at?: string
          marked_by_profile_id: string
          membership_id: string
        }
        Update: {
          marked_at?: string
          marked_by_profile_id?: string
          membership_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_membership_actual_effort_markers_marked_by_fkey"
            columns: ["marked_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_membership_actual_effort_markers_membership_id_fkey"
            columns: ["membership_id"]
            isOneToOne: true
            referencedRelation: "project_memberships"
            referencedColumns: ["id"]
          },
        ]
      }
      project_membership_actual_resource_overrides: {
        Row: {
          is_included: boolean
          membership_id: string
          resource_need_id: string
          updated_at: string
          updated_by_profile_id: string
        }
        Insert: {
          is_included: boolean
          membership_id: string
          resource_need_id: string
          updated_at?: string
          updated_by_profile_id: string
        }
        Update: {
          is_included?: boolean
          membership_id?: string
          resource_need_id?: string
          updated_at?: string
          updated_by_profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_membership_actual_resource_overrides_membership_id_fkey"
            columns: ["membership_id"]
            isOneToOne: false
            referencedRelation: "project_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_membership_actual_resource_overrides_need_id_fkey"
            columns: ["resource_need_id"]
            isOneToOne: false
            referencedRelation: "project_resource_needs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_membership_actual_resource_overrides_updated_by_fkey"
            columns: ["updated_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      project_membership_actual_skill_overrides: {
        Row: {
          is_included: boolean
          membership_id: string
          skill_id: string
          updated_at: string
          updated_by_profile_id: string
        }
        Insert: {
          is_included: boolean
          membership_id: string
          skill_id: string
          updated_at?: string
          updated_by_profile_id: string
        }
        Update: {
          is_included?: boolean
          membership_id?: string
          skill_id?: string
          updated_at?: string
          updated_by_profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_membership_actual_skill_overrides_membership_id_fkey"
            columns: ["membership_id"]
            isOneToOne: false
            referencedRelation: "project_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_membership_actual_skill_overrides_skill_id_fkey"
            columns: ["skill_id"]
            isOneToOne: false
            referencedRelation: "skills"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_membership_actual_skill_overrides_updated_by_fkey"
            columns: ["updated_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      project_membership_resource_commitments: {
        Row: {
          committed_at: string
          membership_id: string
          resource_need_id: string
        }
        Insert: {
          committed_at?: string
          membership_id: string
          resource_need_id: string
        }
        Update: {
          committed_at?: string
          membership_id?: string
          resource_need_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_membership_resource_commitments_membership_id_fkey"
            columns: ["membership_id"]
            isOneToOne: false
            referencedRelation: "project_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_membership_resource_commitments_need_id_fkey"
            columns: ["resource_need_id"]
            isOneToOne: false
            referencedRelation: "project_resource_needs"
            referencedColumns: ["id"]
          },
        ]
      }
      project_membership_resource_coverages: {
        Row: {
          covered_at: string
          membership_id: string
          resource_need_id: string
        }
        Insert: {
          covered_at?: string
          membership_id: string
          resource_need_id: string
        }
        Update: {
          covered_at?: string
          membership_id?: string
          resource_need_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_membership_resource_coverages_commitment_fkey"
            columns: ["membership_id", "resource_need_id"]
            isOneToOne: true
            referencedRelation: "project_membership_resource_commitments"
            referencedColumns: ["membership_id", "resource_need_id"]
          },
        ]
      }
      project_membership_skill_commitments: {
        Row: {
          committed_at: string
          membership_id: string
          skill_id: string
        }
        Insert: {
          committed_at?: string
          membership_id: string
          skill_id: string
        }
        Update: {
          committed_at?: string
          membership_id?: string
          skill_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_membership_skill_commitments_membership_id_fkey"
            columns: ["membership_id"]
            isOneToOne: false
            referencedRelation: "project_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_membership_skill_commitments_skill_id_fkey"
            columns: ["skill_id"]
            isOneToOne: false
            referencedRelation: "skills"
            referencedColumns: ["id"]
          },
        ]
      }
      project_membership_skill_coverages: {
        Row: {
          covered_at: string
          membership_id: string
          skill_id: string
        }
        Insert: {
          covered_at?: string
          membership_id: string
          skill_id: string
        }
        Update: {
          covered_at?: string
          membership_id?: string
          skill_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_membership_skill_coverages_commitment_fkey"
            columns: ["membership_id", "skill_id"]
            isOneToOne: true
            referencedRelation: "project_membership_skill_commitments"
            referencedColumns: ["membership_id", "skill_id"]
          },
        ]
      }
      project_memberships: {
        Row: {
          id: string
          joined_at: string
          left_at: string | null
          originating_request_id: string
          participant_profile_id: string
          project_id: string
          removed_at: string | null
          removed_by_profile_id: string | null
        }
        Insert: {
          id?: string
          joined_at: string
          left_at?: string | null
          originating_request_id: string
          participant_profile_id: string
          project_id: string
          removed_at?: string | null
          removed_by_profile_id?: string | null
        }
        Update: {
          id?: string
          joined_at?: string
          left_at?: string | null
          originating_request_id?: string
          participant_profile_id?: string
          project_id?: string
          removed_at?: string | null
          removed_by_profile_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "project_memberships_originating_request_fkey"
            columns: [
              "originating_request_id",
              "project_id",
              "participant_profile_id",
            ]
            isOneToOne: false
            referencedRelation: "project_join_requests"
            referencedColumns: ["id", "project_id", "requester_profile_id"]
          },
          {
            foreignKeyName: "project_memberships_participant_profile_id_fkey"
            columns: ["participant_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_memberships_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_memberships_removed_by_profile_id_fkey"
            columns: ["removed_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      project_resource_needs: {
        Row: {
          closed_at: string | null
          created_at: string
          details: string | null
          id: string
          project_id: string
          state: string
          title: string
          updated_at: string
        }
        Insert: {
          closed_at?: string | null
          created_at?: string
          details?: string | null
          id?: string
          project_id: string
          state?: string
          title: string
          updated_at?: string
        }
        Update: {
          closed_at?: string | null
          created_at?: string
          details?: string | null
          id?: string
          project_id?: string
          state?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_resource_needs_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      projects: {
        Row: {
          created_at: string
          creator_profile_id: string
          id: string
          project_kind: string
        }
        Insert: {
          created_at: string
          creator_profile_id: string
          id: string
          project_kind: string
        }
        Update: {
          created_at?: string
          creator_profile_id?: string
          id?: string
          project_kind?: string
        }
        Relationships: [
          {
            foreignKeyName: "projects_creator_profile_id_fkey"
            columns: ["creator_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      proposal_meeting_details: {
        Row: {
          exact_location: unknown
          exact_location_visibility: string
          exact_meeting_text: string | null
          proposal_id: string
          updated_at: string
        }
        Insert: {
          exact_location?: unknown
          exact_location_visibility?: string
          exact_meeting_text?: string | null
          proposal_id: string
          updated_at?: string
        }
        Update: {
          exact_location?: unknown
          exact_location_visibility?: string
          exact_meeting_text?: string | null
          proposal_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "proposal_meeting_details_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: true
            referencedRelation: "proposals"
            referencedColumns: ["id"]
          },
        ]
      }
      proposal_skills: {
        Row: {
          created_at: string
          importance: string
          proposal_id: string
          skill_id: string
        }
        Insert: {
          created_at?: string
          importance: string
          proposal_id: string
          skill_id: string
        }
        Update: {
          created_at?: string
          importance?: string
          proposal_id?: string
          skill_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "proposal_skills_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: false
            referencedRelation: "proposals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "proposal_skills_skill_id_fkey"
            columns: ["skill_id"]
            isOneToOne: false
            referencedRelation: "skills"
            referencedColumns: ["id"]
          },
        ]
      }
      proposals: {
        Row: {
          administrative_area: string | null
          approximate_location: unknown
          cancelled_at: string | null
          country_code: string | null
          created_at: string
          creator_profile_id: string
          description: string | null
          ends_at: string | null
          event_timezone: string | null
          id: string
          lifecycle_state: string
          locality: string | null
          public_location_label: string | null
          published_at: string | null
          starts_at: string | null
          summary: string | null
          title: string | null
          updated_at: string
        }
        Insert: {
          administrative_area?: string | null
          approximate_location?: unknown
          cancelled_at?: string | null
          country_code?: string | null
          created_at?: string
          creator_profile_id: string
          description?: string | null
          ends_at?: string | null
          event_timezone?: string | null
          id?: string
          lifecycle_state?: string
          locality?: string | null
          public_location_label?: string | null
          published_at?: string | null
          starts_at?: string | null
          summary?: string | null
          title?: string | null
          updated_at?: string
        }
        Update: {
          administrative_area?: string | null
          approximate_location?: unknown
          cancelled_at?: string | null
          country_code?: string | null
          created_at?: string
          creator_profile_id?: string
          description?: string | null
          ends_at?: string | null
          event_timezone?: string | null
          id?: string
          lifecycle_state?: string
          locality?: string | null
          public_location_label?: string | null
          published_at?: string | null
          starts_at?: string | null
          summary?: string | null
          title?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "proposals_creator_profile_id_fkey"
            columns: ["creator_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      recurring_activities: {
        Row: {
          administrative_area: string | null
          approximate_location: unknown
          country_code: string | null
          created_at: string
          creator_profile_id: string
          description: string | null
          ended_at: string | null
          id: string
          lifecycle_state: string
          locality: string | null
          paused_at: string | null
          public_location_label: string | null
          published_at: string | null
          resumed_at: string | null
          summary: string | null
          title: string | null
          topic: string | null
          updated_at: string
        }
        Insert: {
          administrative_area?: string | null
          approximate_location?: unknown
          country_code?: string | null
          created_at?: string
          creator_profile_id: string
          description?: string | null
          ended_at?: string | null
          id?: string
          lifecycle_state?: string
          locality?: string | null
          paused_at?: string | null
          public_location_label?: string | null
          published_at?: string | null
          resumed_at?: string | null
          summary?: string | null
          title?: string | null
          topic?: string | null
          updated_at?: string
        }
        Update: {
          administrative_area?: string | null
          approximate_location?: unknown
          country_code?: string | null
          created_at?: string
          creator_profile_id?: string
          description?: string | null
          ended_at?: string | null
          id?: string
          lifecycle_state?: string
          locality?: string | null
          paused_at?: string | null
          public_location_label?: string | null
          published_at?: string | null
          resumed_at?: string | null
          summary?: string | null
          title?: string | null
          topic?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "recurring_activities_creator_profile_id_fkey"
            columns: ["creator_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      recurring_activity_meeting_details: {
        Row: {
          exact_location: unknown
          exact_location_visibility: string
          exact_meeting_text: string | null
          recurring_activity_id: string
          updated_at: string
        }
        Insert: {
          exact_location?: unknown
          exact_location_visibility?: string
          exact_meeting_text?: string | null
          recurring_activity_id: string
          updated_at?: string
        }
        Update: {
          exact_location?: unknown
          exact_location_visibility?: string
          exact_meeting_text?: string | null
          recurring_activity_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "recurring_activity_meeting_details_activity_id_fkey"
            columns: ["recurring_activity_id"]
            isOneToOne: true
            referencedRelation: "recurring_activities"
            referencedColumns: ["id"]
          },
        ]
      }
      recurring_activity_schedules: {
        Row: {
          created_at: string
          day_of_month: number | null
          duration_minutes: number
          effective_from: string
          effective_until: string | null
          event_timezone: string
          id: string
          local_start_time: string
          recurrence_type: string
          recurring_activity_id: string
          superseded_at: string | null
          weekday: number | null
        }
        Insert: {
          created_at?: string
          day_of_month?: number | null
          duration_minutes: number
          effective_from: string
          effective_until?: string | null
          event_timezone: string
          id?: string
          local_start_time: string
          recurrence_type: string
          recurring_activity_id: string
          superseded_at?: string | null
          weekday?: number | null
        }
        Update: {
          created_at?: string
          day_of_month?: number | null
          duration_minutes?: number
          effective_from?: string
          effective_until?: string | null
          event_timezone?: string
          id?: string
          local_start_time?: string
          recurrence_type?: string
          recurring_activity_id?: string
          superseded_at?: string | null
          weekday?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "recurring_activity_schedules_activity_id_fkey"
            columns: ["recurring_activity_id"]
            isOneToOne: false
            referencedRelation: "recurring_activities"
            referencedColumns: ["id"]
          },
        ]
      }
      resource_exchange_agreement_events: {
        Row: {
          actor_profile_id: string
          agreement_id: string
          created_at: string
          event_kind: string
          id: string
          leg_kind: string | null
          terms_id: string | null
        }
        Insert: {
          actor_profile_id: string
          agreement_id: string
          created_at?: string
          event_kind: string
          id?: string
          leg_kind?: string | null
          terms_id?: string | null
        }
        Update: {
          actor_profile_id?: string
          agreement_id?: string
          created_at?: string
          event_kind?: string
          id?: string
          leg_kind?: string | null
          terms_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "resource_exchange_agreement_events_actor_profile_id_fkey"
            columns: ["actor_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_exchange_agreement_events_agreement_id_fkey"
            columns: ["agreement_id"]
            isOneToOne: false
            referencedRelation: "resource_exchange_agreements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_exchange_agreement_events_agreement_terms_fkey"
            columns: ["agreement_id", "terms_id"]
            isOneToOne: false
            referencedRelation: "resource_exchange_agreement_terms"
            referencedColumns: ["agreement_id", "id"]
          },
        ]
      }
      resource_exchange_agreement_terms: {
        Row: {
          agreement_id: string
          created_at: string
          id: string
          listing_description_snapshot: string
          listing_title_snapshot: string
          owner_lend_ends_at: string | null
          owner_lend_starts_at: string | null
          owner_transfer_kind: string
          private_note: string | null
          proposed_by_profile_id: string
          requester_lend_ends_at: string | null
          requester_lend_starts_at: string | null
          requester_resource_description: string | null
          requester_transfer_kind: string
          version_number: number
        }
        Insert: {
          agreement_id: string
          created_at?: string
          id?: string
          listing_description_snapshot: string
          listing_title_snapshot: string
          owner_lend_ends_at?: string | null
          owner_lend_starts_at?: string | null
          owner_transfer_kind: string
          private_note?: string | null
          proposed_by_profile_id: string
          requester_lend_ends_at?: string | null
          requester_lend_starts_at?: string | null
          requester_resource_description?: string | null
          requester_transfer_kind: string
          version_number: number
        }
        Update: {
          agreement_id?: string
          created_at?: string
          id?: string
          listing_description_snapshot?: string
          listing_title_snapshot?: string
          owner_lend_ends_at?: string | null
          owner_lend_starts_at?: string | null
          owner_transfer_kind?: string
          private_note?: string | null
          proposed_by_profile_id?: string
          requester_lend_ends_at?: string | null
          requester_lend_starts_at?: string | null
          requester_resource_description?: string | null
          requester_transfer_kind?: string
          version_number?: number
        }
        Relationships: [
          {
            foreignKeyName: "resource_exchange_agreement_terms_agreement_id_fkey"
            columns: ["agreement_id"]
            isOneToOne: false
            referencedRelation: "resource_exchange_agreements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_exchange_agreement_terms_proposer_fkey"
            columns: ["proposed_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      resource_exchange_agreements: {
        Row: {
          cancelled_at: string | null
          cancelled_by_profile_id: string | null
          completed_at: string | null
          created_at: string
          current_terms_accepted_at: string | null
          current_terms_id: string | null
          id: string
          lifecycle_state: string
          pending_terms_id: string | null
          request_id: string
        }
        Insert: {
          cancelled_at?: string | null
          cancelled_by_profile_id?: string | null
          completed_at?: string | null
          created_at?: string
          current_terms_accepted_at?: string | null
          current_terms_id?: string | null
          id?: string
          lifecycle_state?: string
          pending_terms_id?: string | null
          request_id: string
        }
        Update: {
          cancelled_at?: string | null
          cancelled_by_profile_id?: string | null
          completed_at?: string | null
          created_at?: string
          current_terms_accepted_at?: string | null
          current_terms_id?: string | null
          id?: string
          lifecycle_state?: string
          pending_terms_id?: string | null
          request_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "resource_exchange_agreements_cancelled_by_profile_id_fkey"
            columns: ["cancelled_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_exchange_agreements_current_terms_fkey"
            columns: ["id", "current_terms_id"]
            isOneToOne: false
            referencedRelation: "resource_exchange_agreement_terms"
            referencedColumns: ["agreement_id", "id"]
          },
          {
            foreignKeyName: "resource_exchange_agreements_pending_terms_fkey"
            columns: ["id", "pending_terms_id"]
            isOneToOne: false
            referencedRelation: "resource_exchange_agreement_terms"
            referencedColumns: ["agreement_id", "id"]
          },
          {
            foreignKeyName: "resource_exchange_agreements_request_id_fkey"
            columns: ["request_id"]
            isOneToOne: true
            referencedRelation: "resource_listing_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      resource_listing_requests: {
        Row: {
          coordination_closed_at: string | null
          coordination_closed_by_profile_id: string | null
          created_at: string
          id: string
          listing_id: string
          request_message: string | null
          requester_profile_id: string
          resolved_at: string | null
          resolved_by_profile_id: string | null
          status: string
        }
        Insert: {
          coordination_closed_at?: string | null
          coordination_closed_by_profile_id?: string | null
          created_at?: string
          id?: string
          listing_id: string
          request_message?: string | null
          requester_profile_id: string
          resolved_at?: string | null
          resolved_by_profile_id?: string | null
          status?: string
        }
        Update: {
          coordination_closed_at?: string | null
          coordination_closed_by_profile_id?: string | null
          created_at?: string
          id?: string
          listing_id?: string
          request_message?: string | null
          requester_profile_id?: string
          resolved_at?: string | null
          resolved_by_profile_id?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "resource_listing_requests_coordination_closed_by_fkey"
            columns: ["coordination_closed_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_listing_requests_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "resource_listings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_listing_requests_requester_profile_id_fkey"
            columns: ["requester_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_listing_requests_resolved_by_profile_id_fkey"
            columns: ["resolved_by_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      resource_listings: {
        Row: {
          administrative_area: string | null
          closed_at: string | null
          country_code: string | null
          created_at: string
          description: string | null
          id: string
          lifecycle_state: string
          listing_mode: string
          locality: string | null
          owner_profile_id: string
          public_location_label: string | null
          published_at: string | null
          title: string | null
          updated_at: string
        }
        Insert: {
          administrative_area?: string | null
          closed_at?: string | null
          country_code?: string | null
          created_at?: string
          description?: string | null
          id?: string
          lifecycle_state?: string
          listing_mode: string
          locality?: string | null
          owner_profile_id: string
          public_location_label?: string | null
          published_at?: string | null
          title?: string | null
          updated_at?: string
        }
        Update: {
          administrative_area?: string | null
          closed_at?: string | null
          country_code?: string | null
          created_at?: string
          description?: string | null
          id?: string
          lifecycle_state?: string
          listing_mode?: string
          locality?: string | null
          owner_profile_id?: string
          public_location_label?: string | null
          published_at?: string | null
          title?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "resource_listings_owner_profile_id_fkey"
            columns: ["owner_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      resource_request_chat_messages: {
        Row: {
          body: string
          chat_id: string
          created_at: string
          id: string
          sender_profile_id: string
        }
        Insert: {
          body: string
          chat_id: string
          created_at?: string
          id?: string
          sender_profile_id: string
        }
        Update: {
          body?: string
          chat_id?: string
          created_at?: string
          id?: string
          sender_profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "resource_request_chat_messages_chat_id_fkey"
            columns: ["chat_id"]
            isOneToOne: false
            referencedRelation: "resource_request_chats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_request_chat_messages_sender_profile_id_fkey"
            columns: ["sender_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      resource_request_chats: {
        Row: {
          activated_at: string
          id: string
          request_id: string
        }
        Insert: {
          activated_at: string
          id?: string
          request_id: string
        }
        Update: {
          activated_at?: string
          id?: string
          request_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "resource_request_chats_request_id_fkey"
            columns: ["request_id"]
            isOneToOne: true
            referencedRelation: "resource_listing_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      resource_saved_searches: {
        Row: {
          created_at: string
          id: string
          listing_mode: string | null
          locality: string | null
          profile_id: string
          query: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          listing_mode?: string | null
          locality?: string | null
          profile_id: string
          query?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          listing_mode?: string | null
          locality?: string | null
          profile_id?: string
          query?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "resource_saved_searches_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      skill_categories: {
        Row: {
          id: string
          label: string
          slug: string
          sort_order: number
        }
        Insert: {
          id: string
          label: string
          slug: string
          sort_order: number
        }
        Update: {
          id?: string
          label?: string
          slug?: string
          sort_order?: number
        }
        Relationships: []
      }
      skills: {
        Row: {
          category_id: string
          id: string
          label: string
          slug: string
          sort_order: number
        }
        Insert: {
          category_id: string
          id: string
          label: string
          slug: string
          sort_order: number
        }
        Update: {
          category_id?: string
          id?: string
          label?: string
          slug?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "skills_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "skill_categories"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      accept_project_join_request:
        | {
            Args: {
              p_expected_creator_profile_id: string
              p_request_id: string
            }
            Returns: string
          }
        | {
            Args: {
              p_already_found_resource_need_ids: string[]
              p_already_found_skill_ids: string[]
              p_expected_creator_profile_id: string
              p_extra_resource_need_ids: string[]
              p_extra_skill_ids: string[]
              p_needed_resource_need_ids: string[]
              p_needed_skill_ids: string[]
              p_request_id: string
            }
            Returns: string
          }
      accept_resource_exchange_terms: {
        Args: {
          p_agreement_id: string
          p_expected_pending_terms_id: string
          p_expected_profile_id: string
        }
        Returns: string
      }
      accept_resource_listing_request: {
        Args: { p_expected_owner_profile_id: string; p_request_id: string }
        Returns: string
      }
      acknowledge_project_requirement_attention: {
        Args: {
          p_expected_profile_id: string
          p_project_id: string
          p_through_system_event_id: string
        }
        Returns: string
      }
      add_moderation_case_note: {
        Args: {
          p_body: string
          p_case_id: string
          p_expected_staff_profile_id: string
        }
        Returns: {
          created_at: string
          note_id: string
        }[]
      }
      can_read_public_project_creator_photo_object: {
        Args: { p_object_path: string }
        Returns: boolean
      }
      can_read_public_resource_listing_owner_photo_object: {
        Args: { p_object_path: string }
        Returns: boolean
      }
      cancel_proposal: {
        Args: { p_expected_creator_profile_id: string; p_proposal_id: string }
        Returns: string
      }
      cancel_resource_exchange_agreement: {
        Args: { p_agreement_id: string; p_expected_profile_id: string }
        Returns: string
      }
      check_resource_exchange_pending_loan_availability: {
        Args: {
          p_agreement_id: string
          p_expected_pending_terms_id: string
          p_expected_profile_id: string
        }
        Returns: {
          is_available: boolean
          is_lend: boolean
        }[]
      }
      claim_project_requirement: {
        Args: {
          p_expected_participant_profile_id: string
          p_project_id: string
          p_requirement_id: string
          p_requirement_kind: string
        }
        Returns: string
      }
      clear_own_profile_photo: {
        Args: { p_expected_profile_id: string }
        Returns: string
      }
      close_project_resource_need: {
        Args: {
          p_expected_creator_profile_id: string
          p_resource_need_id: string
        }
        Returns: string
      }
      close_resource_listing: {
        Args: { p_expected_owner_profile_id: string; p_listing_id: string }
        Returns: string
      }
      create_project_resource_need: {
        Args: {
          p_details?: string
          p_expected_creator_profile_id: string
          p_project_id: string
          p_title: string
        }
        Returns: string
      }
      create_proposal_draft: {
        Args: {
          p_administrative_area: string
          p_country_code: string
          p_description: string
          p_ends_at: string
          p_event_timezone: string
          p_exact_location_visibility: string
          p_exact_meeting_text: string
          p_expected_creator_profile_id: string
          p_locality: string
          p_public_location_label: string
          p_skill_ids: string[]
          p_skill_importances: string[]
          p_starts_at: string
          p_summary: string
          p_title: string
        }
        Returns: string
      }
      create_recurring_activity_draft: {
        Args: {
          p_administrative_area: string
          p_country_code: string
          p_day_of_month: number
          p_description: string
          p_duration_minutes: number
          p_effective_from: string
          p_event_timezone: string
          p_exact_location_visibility: string
          p_exact_meeting_text: string
          p_expected_creator_profile_id: string
          p_local_start_time: string
          p_locality: string
          p_public_location_label: string
          p_recurrence_type: string
          p_summary: string
          p_title: string
          p_topic: string
          p_weekday: number
        }
        Returns: string
      }
      create_resource_listing_draft: {
        Args: {
          p_administrative_area: string
          p_country_code: string
          p_description: string
          p_expected_owner_profile_id: string
          p_listing_mode: string
          p_locality: string
          p_public_location_label: string
          p_title: string
        }
        Returns: string
      }
      create_resource_saved_search: {
        Args: {
          p_expected_profile_id: string
          p_listing_mode: string
          p_locality: string
          p_query: string
        }
        Returns: string
      }
      delete_resource_saved_search: {
        Args: { p_expected_profile_id: string; p_saved_search_id: string }
        Returns: string
      }
      end_recurring_activity: {
        Args: {
          p_expected_creator_profile_id: string
          p_recurring_activity_id: string
        }
        Returns: string
      }
      get_moderation_case_detail: {
        Args: { p_case_id: string; p_expected_staff_profile_id: string }
        Returns: {
          case_id: string
          category: string
          completed_at: string
          context_summary: string
          created_at: string
          events: Json
          explanation: string
          notes: Json
          project_context_id: string
          reporter_display_name: string
          reporter_profile_id: string
          resource_chat_context_id: string
          resource_listing_context_id: string
          resource_request_context_id: string
          state: string
          state_version: number
          subject_display_name: string
          subject_profile_id: string
          target_kind: string
          target_summary: string
        }[]
      }
      get_own_moderation_staff_access: {
        Args: { p_expected_profile_id: string }
        Returns: {
          staff_role: string
        }[]
      }
      get_own_participation_request_message_item: {
        Args: { p_expected_profile_id: string; p_request_id: string }
        Returns: {
          activity_at: string
          created_at: string
          creator_display_name: string
          creator_profile_id: string
          project_id: string
          project_kind: string
          project_title: string
          request_id: string
          request_message: string
          requester_display_name: string
          requester_profile_id: string
          resolved_at: string
          status: string
          viewer_role: string
        }[]
      }
      get_own_profile_photo: {
        Args: { p_expected_profile_id: string }
        Returns: {
          audience: string
          created_at: string
          object_path: string
          profile_id: string
          updated_at: string
        }[]
      }
      get_own_project_group_chat: {
        Args: { p_expected_profile_id: string; p_project_id: string }
        Returns: {
          activated_at: string
          chat_id: string
          has_current_entitlement: boolean
          has_history_entitlement: boolean
          project_id: string
          project_kind: string
          viewer_role: string
        }[]
      }
      get_own_project_requirement_attention: {
        Args: { p_expected_profile_id: string; p_project_id: string }
        Returns: {
          chat_id: string
          has_unseen_resurfaced_need: boolean
          latest_unseen_event_at: string
          latest_unseen_event_id: string
        }[]
      }
      get_own_proposal: {
        Args: { p_expected_creator_profile_id: string; p_proposal_id: string }
        Returns: {
          administrative_area: string
          cancelled_at: string
          country_code: string
          created_at: string
          derived_status: string
          description: string
          ends_at: string
          event_timezone: string
          exact_location_visibility: string
          exact_meeting_text: string
          lifecycle_state: string
          locality: string
          proposal_id: string
          public_location_label: string
          published_at: string
          skills: Json
          starts_at: string
          summary: string
          title: string
          updated_at: string
        }[]
      }
      get_own_recurring_activity: {
        Args: {
          p_expected_creator_profile_id: string
          p_recurring_activity_id: string
        }
        Returns: {
          administrative_area: string
          country_code: string
          created_at: string
          current_schedule: Json
          description: string
          ended_at: string
          exact_location_visibility: string
          exact_meeting_text: string
          lifecycle_state: string
          locality: string
          paused_at: string
          public_location_label: string
          published_at: string
          recurring_activity_id: string
          resumed_at: string
          schedule_history: Json
          summary: string
          title: string
          topic: string
          updated_at: string
        }[]
      }
      get_own_resource_listing: {
        Args: { p_expected_owner_profile_id: string; p_listing_id: string }
        Returns: {
          administrative_area: string
          closed_at: string
          country_code: string
          created_at: string
          description: string
          lifecycle_state: string
          listing_id: string
          listing_mode: string
          locality: string
          owner_profile_id: string
          public_location_label: string
          published_at: string
          title: string
          updated_at: string
        }[]
      }
      get_own_resource_request_chat: {
        Args: { p_chat_id: string; p_expected_profile_id: string }
        Returns: {
          activated_at: string
          activity_at: string
          agreement_id: string
          agreement_lifecycle: string
          chat_id: string
          coordination_closed_at: string
          has_send_entitlement: boolean
          last_visible_message_at: string
          last_visible_message_body: string
          last_visible_message_id: string
          last_visible_sender_display_name: string
          last_visible_sender_profile_id: string
          listing_id: string
          listing_title: string
          owner_display_name: string
          owner_profile_id: string
          request_id: string
          requester_display_name: string
          requester_profile_id: string
          viewer_role: string
        }[]
      }
      get_own_resource_saved_search: {
        Args: { p_expected_profile_id: string; p_saved_search_id: string }
        Returns: {
          created_at: string
          listing_mode: string
          locality: string
          query: string
          saved_search_id: string
          updated_at: string
        }[]
      }
      get_own_structured_request_message_item: {
        Args: {
          p_expected_profile_id: string
          p_item_kind: string
          p_request_id: string
        }
        Returns: {
          activity_at: string
          coordination_closed_at: string
          created_at: string
          item_kind: string
          project_creator_display_name: string
          project_creator_profile_id: string
          project_id: string
          project_kind: string
          project_title: string
          request_id: string
          request_message: string
          requester_display_name: string
          requester_profile_id: string
          resolved_at: string
          resource_agreement_id: string
          resource_chat_id: string
          resource_listing_id: string
          resource_listing_lifecycle: string
          resource_listing_mode: string
          resource_listing_title: string
          resource_owner_display_name: string
          resource_owner_profile_id: string
          status: string
          viewer_role: string
        }[]
      }
      get_own_unread_notification_count: {
        Args: { p_expected_profile_id: string }
        Returns: number
      }
      get_profile_photo_for_viewer: {
        Args: { p_profile_id: string }
        Returns: {
          object_path: string
          profile_id: string
          updated_at: string
        }[]
      }
      get_project_creator_profile_photo_for_viewer: {
        Args: { p_project_id: string }
        Returns: {
          object_path: string
          profile_id: string
          updated_at: string
        }[]
      }
      get_project_participant_meeting_details: {
        Args: { p_expected_profile_id: string; p_project_id: string }
        Returns: {
          exact_location: unknown
          exact_meeting_text: string
          project_id: string
          project_kind: string
        }[]
      }
      get_public_profile: {
        Args: { p_profile_id: string }
        Returns: {
          bio: string
          display_name: string
          profile_id: string
          skills: Json
        }[]
      }
      get_public_proposal: {
        Args: { p_proposal_id: string }
        Returns: {
          administrative_area: string
          country_code: string
          creator_display_name: string
          creator_profile_id: string
          derived_status: string
          description: string
          ends_at: string
          event_timezone: string
          exact_location_restricted: boolean
          exact_meeting_text: string
          locality: string
          proposal_id: string
          public_location_label: string
          skills: Json
          starts_at: string
          summary: string
          title: string
        }[]
      }
      get_public_recurring_activity: {
        Args: {
          p_occurrence_limit?: number
          p_recurring_activity_id: string
          p_reference_time?: string
        }
        Returns: {
          administrative_area: string
          country_code: string
          creator_display_name: string
          creator_profile_id: string
          day_of_month: number
          description: string
          duration_minutes: number
          event_timezone: string
          exact_location_restricted: boolean
          exact_meeting_text: string
          lifecycle_state: string
          local_start_time: string
          locality: string
          next_occurrences: Json
          public_location_label: string
          recurrence_type: string
          recurring_activity_id: string
          schedule_effective_from: string
          summary: string
          title: string
          topic: string
          weekday: number
        }[]
      }
      get_public_resource_listing: {
        Args: { p_listing_id: string }
        Returns: {
          active_request_count: number
          administrative_area: string
          country_code: string
          description: string
          listing_id: string
          listing_mode: string
          locality: string
          owner_display_name: string
          owner_profile_id: string
          public_location_label: string
          published_at: string
          title: string
        }[]
      }
      get_resource_exchange_agreement: {
        Args: { p_expected_profile_id: string; p_request_id: string }
        Returns: {
          agreement_id: string
          cancelled_at: string
          cancelled_by_profile_id: string
          completed_at: string
          created_at: string
          current_terms_accepted_at: string
          current_terms_id: string
          lifecycle_state: string
          listing_id: string
          owner_lend_return_overdue: boolean
          owner_profile_id: string
          pending_terms_id: string
          request_id: string
          requester_lend_return_overdue: boolean
          requester_profile_id: string
        }[]
      }
      get_resource_listing_owner_profile_photo_for_viewer: {
        Args: { p_listing_id: string }
        Returns: {
          object_path: string
          profile_id: string
          updated_at: string
        }[]
      }
      get_resource_listing_request: {
        Args: { p_expected_profile_id: string; p_request_id: string }
        Returns: {
          coordination_closed_at: string
          coordination_closed_by_profile_id: string
          created_at: string
          listing_id: string
          listing_lifecycle: string
          listing_mode: string
          listing_title: string
          owner_display_name: string
          owner_profile_id: string
          request_id: string
          request_message: string
          requester_display_name: string
          requester_profile_id: string
          resolved_at: string
          resolved_by_profile_id: string
          status: string
        }[]
      }
      leave_project: {
        Args: {
          p_expected_participant_profile_id: string
          p_membership_id: string
        }
        Returns: string
      }
      list_moderation_cases: {
        Args: {
          p_before_case_id?: string
          p_before_created_at?: string
          p_expected_staff_profile_id: string
          p_limit?: number
          p_state?: string
        }
        Returns: {
          case_id: string
          category: string
          context_summary: string
          created_at: string
          state: string
          state_version: number
          subject_display_name: string
          subject_profile_id: string
          target_kind: string
          target_summary: string
        }[]
      }
      list_own_message_chat_items: {
        Args: {
          p_cursor_activity_at?: string
          p_cursor_chat_id?: string
          p_cursor_item_kind?: string
          p_expected_profile_id: string
          p_limit: number
        }
        Returns: {
          activity_at: string
          agreement_lifecycle: string
          chat_id: string
          coordination_closed_at: string
          display_title: string
          is_read_only: boolean
          item_kind: string
          last_visible_message_at: string
          last_visible_message_body: string
          last_visible_message_id: string
          last_visible_sender_display_name: string
          last_visible_sender_profile_id: string
          project_id: string
          project_kind: string
          resource_agreement_id: string
          resource_listing_id: string
          resource_request_id: string
          viewer_role: string
        }[]
      }
      list_own_moderation_reports: {
        Args: {
          p_before_created_at?: string
          p_before_report_id?: string
          p_expected_reporter_profile_id: string
          p_limit?: number
        }
        Returns: {
          case_id: string
          category: string
          context_summary: string
          created_at: string
          explanation: string
          report_id: string
          state: string
          target_kind: string
          target_summary: string
        }[]
      }
      list_own_notification_preferences: {
        Args: { p_expected_profile_id: string }
        Returns: {
          category_slug: string
          has_override: boolean
          in_app_enabled: boolean
          push_enabled: boolean
          sort_order: number
          user_configurable: boolean
        }[]
      }
      list_own_notifications: {
        Args: {
          p_cursor_created_at?: string
          p_cursor_id?: string
          p_expected_profile_id: string
          p_limit?: number
        }
        Returns: {
          actor_display_name: string
          actor_profile_id: string
          category_slug: string
          chat_id: string
          created_at: string
          destination_kind: string
          message_id: string
          notification_id: string
          notification_kind: string
          project_id: string
          project_kind: string
          project_title: string
          read_at: string
          request_id: string
          resource_agreement_event_id: string
          resource_agreement_id: string
          resource_chat_id: string
          resource_chat_message_id: string
          resource_exchange_event_kind: string
          resource_exchange_leg_kind: string
          resource_listing_id: string
          resource_listing_title: string
          resource_request_id: string
        }[]
      }
      list_own_participation_request_message_items: {
        Args: {
          p_cursor_activity_at?: string
          p_cursor_request_id?: string
          p_expected_profile_id: string
          p_limit: number
        }
        Returns: {
          activity_at: string
          created_at: string
          creator_display_name: string
          creator_profile_id: string
          project_id: string
          project_kind: string
          project_title: string
          request_id: string
          request_message: string
          requester_display_name: string
          requester_profile_id: string
          resolved_at: string
          status: string
          viewer_role: string
        }[]
      }
      list_own_pending_requested_proposals: {
        Args: {
          p_expected_requester_profile_id: string
          p_locality?: string
          p_skill_ids?: string[]
        }
        Returns: {
          administrative_area: string
          country_code: string
          derived_status: string
          ends_at: string
          event_timezone: string
          locality: string
          proposal_id: string
          public_location_label: string
          request_created_at: string
          request_id: string
          skills: Json
          starts_at: string
          summary: string
          title: string
        }[]
      }
      list_own_pending_requested_recurring_activities: {
        Args: {
          p_expected_requester_profile_id: string
          p_locality?: string
          p_reference_time: string
        }
        Returns: {
          administrative_area: string
          country_code: string
          day_of_month: number
          duration_minutes: number
          event_timezone: string
          local_start_time: string
          locality: string
          next_ends_at: string
          next_starts_at: string
          public_location_label: string
          recurrence_type: string
          recurring_activity_id: string
          request_created_at: string
          request_id: string
          schedule_effective_from: string
          summary: string
          title: string
          topic: string
          weekday: number
        }[]
      }
      list_own_project_chat_feed: {
        Args: {
          p_before_created_at?: string
          p_before_item_id?: string
          p_before_item_kind?: string
          p_chat_id: string
          p_expected_profile_id: string
          p_limit: number
        }
        Returns: {
          body: string
          chat_id: string
          created_at: string
          item_id: string
          item_kind: string
          requirement_id: string
          requirement_kind: string
          requirement_label: string
          sender_display_name: string
          sender_profile_id: string
          system_event_kind: string
        }[]
      }
      list_own_project_chat_messages: {
        Args: {
          p_before_created_at?: string
          p_before_message_id?: string
          p_chat_id: string
          p_expected_profile_id: string
          p_limit: number
        }
        Returns: {
          body: string
          chat_id: string
          created_at: string
          message_id: string
          sender_display_name: string
          sender_profile_id: string
        }[]
      }
      list_own_project_group_chats: {
        Args: {
          p_before_activity_at?: string
          p_before_chat_id?: string
          p_expected_profile_id: string
          p_limit: number
        }
        Returns: {
          activated_at: string
          activity_at: string
          chat_id: string
          has_current_entitlement: boolean
          has_history_entitlement: boolean
          last_visible_message_at: string
          last_visible_message_body: string
          last_visible_message_id: string
          last_visible_sender_display_name: string
          last_visible_sender_profile_id: string
          project_id: string
          project_kind: string
          project_title: string
          viewer_role: string
        }[]
      }
      list_own_project_join_request_contribution_selections: {
        Args: { p_expected_profile_id: string; p_request_id: string }
        Returns: {
          label: string
          selection_id: string
          selection_kind: string
        }[]
      }
      list_own_project_join_requests: {
        Args: { p_expected_requester_profile_id: string }
        Returns: {
          created_at: string
          project_id: string
          project_kind: string
          request_id: string
          request_message: string
          resolved_at: string
          status: string
        }[]
      }
      list_own_project_membership_commitment_options: {
        Args: { p_expected_profile_id: string; p_membership_id: string }
        Returns: {
          label: string
          option_id: string
          option_kind: string
        }[]
      }
      list_own_project_membership_commitments: {
        Args: { p_expected_profile_id: string; p_membership_id: string }
        Returns: {
          commitment_id: string
          commitment_kind: string
          label: string
        }[]
      }
      list_own_project_memberships: {
        Args: { p_expected_participant_profile_id: string }
        Returns: {
          joined_at: string
          left_at: string
          membership_id: string
          membership_status: string
          originating_request_id: string
          project_id: string
          project_kind: string
          removed_at: string
        }[]
      }
      list_own_project_resource_needs: {
        Args: { p_expected_creator_profile_id: string; p_project_id: string }
        Returns: {
          closed_at: string
          created_at: string
          details: string
          project_id: string
          project_kind: string
          resource_need_id: string
          state: string
          title: string
          updated_at: string
        }[]
      }
      list_own_proposals: {
        Args: { p_expected_creator_profile_id: string }
        Returns: {
          administrative_area: string
          cancelled_at: string
          country_code: string
          created_at: string
          derived_status: string
          description: string
          ends_at: string
          event_timezone: string
          exact_location_visibility: string
          exact_meeting_text: string
          lifecycle_state: string
          locality: string
          proposal_id: string
          public_location_label: string
          published_at: string
          skills: Json
          starts_at: string
          summary: string
          title: string
          updated_at: string
        }[]
      }
      list_own_recurring_activities: {
        Args: { p_expected_creator_profile_id: string }
        Returns: {
          administrative_area: string
          country_code: string
          created_at: string
          current_schedule: Json
          description: string
          ended_at: string
          exact_location_visibility: string
          exact_meeting_text: string
          lifecycle_state: string
          locality: string
          paused_at: string
          public_location_label: string
          published_at: string
          recurring_activity_id: string
          resumed_at: string
          schedule_history: Json
          summary: string
          title: string
          topic: string
          updated_at: string
        }[]
      }
      list_own_resource_listing_requests: {
        Args: { p_expected_requester_profile_id: string }
        Returns: {
          coordination_closed_at: string
          coordination_closed_by_profile_id: string
          created_at: string
          listing_id: string
          listing_lifecycle: string
          listing_mode: string
          listing_title: string
          owner_display_name: string
          owner_profile_id: string
          request_id: string
          request_message: string
          resolved_at: string
          status: string
        }[]
      }
      list_own_resource_listings: {
        Args: { p_expected_owner_profile_id: string }
        Returns: {
          administrative_area: string
          closed_at: string
          country_code: string
          created_at: string
          description: string
          lifecycle_state: string
          listing_id: string
          listing_mode: string
          locality: string
          owner_profile_id: string
          public_location_label: string
          published_at: string
          title: string
          updated_at: string
        }[]
      }
      list_own_resource_request_chat_messages: {
        Args: {
          p_before_created_at?: string
          p_before_message_id?: string
          p_chat_id: string
          p_expected_profile_id: string
          p_limit: number
        }
        Returns: {
          body: string
          chat_id: string
          created_at: string
          message_id: string
          sender_display_name: string
          sender_profile_id: string
        }[]
      }
      list_own_resource_request_chats: {
        Args: {
          p_before_activity_at?: string
          p_before_chat_id?: string
          p_expected_profile_id: string
          p_limit: number
        }
        Returns: {
          activated_at: string
          activity_at: string
          agreement_id: string
          agreement_lifecycle: string
          chat_id: string
          coordination_closed_at: string
          has_send_entitlement: boolean
          last_visible_message_at: string
          last_visible_message_body: string
          last_visible_message_id: string
          last_visible_sender_display_name: string
          last_visible_sender_profile_id: string
          listing_id: string
          listing_title: string
          owner_display_name: string
          owner_profile_id: string
          request_id: string
          requester_display_name: string
          requester_profile_id: string
          viewer_role: string
        }[]
      }
      list_own_resource_saved_searches: {
        Args: {
          p_cursor_id?: string
          p_cursor_updated_at?: string
          p_expected_profile_id: string
          p_limit?: number
        }
        Returns: {
          created_at: string
          listing_mode: string
          locality: string
          query: string
          saved_search_id: string
          updated_at: string
        }[]
      }
      list_own_structured_request_message_items: {
        Args: {
          p_cursor_activity_at?: string
          p_cursor_item_kind?: string
          p_cursor_request_id?: string
          p_expected_profile_id: string
          p_limit: number
        }
        Returns: {
          activity_at: string
          coordination_closed_at: string
          created_at: string
          item_kind: string
          project_creator_display_name: string
          project_creator_profile_id: string
          project_id: string
          project_kind: string
          project_title: string
          request_id: string
          request_message: string
          requester_display_name: string
          requester_profile_id: string
          resolved_at: string
          resource_agreement_id: string
          resource_chat_id: string
          resource_listing_id: string
          resource_listing_lifecycle: string
          resource_listing_mode: string
          resource_listing_title: string
          resource_owner_display_name: string
          resource_owner_profile_id: string
          status: string
          viewer_role: string
        }[]
      }
      list_owned_resource_listing_loan_schedule: {
        Args: { p_expected_owner_profile_id: string; p_listing_id: string }
        Returns: {
          agreement_id: string
          agreement_lifecycle: string
          ends_at: string
          is_at_risk: boolean
          is_overdue: boolean
          listing_id: string
          request_id: string
          requester_display_name: string
          requester_profile_id: string
          starts_at: string
          terms_id: string
        }[]
      }
      list_profile_photos_for_viewer: {
        Args: { p_profile_ids: string[] }
        Returns: {
          object_path: string
          profile_id: string
          updated_at: string
        }[]
      }
      list_project_join_requests: {
        Args: { p_expected_creator_profile_id: string; p_project_id: string }
        Returns: {
          created_at: string
          request_id: string
          request_message: string
          requester_display_name: string
          requester_profile_id: string
          resolved_at: string
          resolved_by_profile_id: string
          status: string
        }[]
      }
      list_project_live_requirement_coverage: {
        Args: { p_expected_profile_id: string; p_project_id: string }
        Returns: {
          importance: string
          is_covered: boolean
          is_manually_covered: boolean
          label: string
          requirement_id: string
          requirement_kind: string
          viewer_is_covering: boolean
        }[]
      }
      list_project_members: {
        Args: { p_expected_creator_profile_id: string; p_project_id: string }
        Returns: {
          joined_at: string
          left_at: string
          membership_id: string
          membership_status: string
          originating_request_id: string
          participant_display_name: string
          participant_profile_id: string
          removed_at: string
          removed_by_profile_id: string
        }[]
      }
      list_project_membership_actual_contribution_options: {
        Args: { p_expected_creator_profile_id: string; p_membership_id: string }
        Returns: {
          label: string
          option_id: string
          option_kind: string
        }[]
      }
      list_project_membership_actual_contributions: {
        Args: { p_expected_profile_id: string; p_membership_id: string }
        Returns: {
          attribution_source: string
          contribution_id: string
          contribution_kind: string
          label: string
        }[]
      }
      list_project_resource_need_listing_matches: {
        Args: {
          p_cursor_listing_id?: string
          p_cursor_location_match_kind?: string
          p_cursor_published_at?: string
          p_cursor_text_match_kind?: string
          p_expected_creator_profile_id: string
          p_limit?: number
          p_listing_mode?: string
          p_location_scope: string
          p_resource_need_id: string
        }
        Returns: {
          active_request_count: number
          administrative_area: string
          country_code: string
          description: string
          listing_id: string
          listing_mode: string
          locality: string
          location_match_kind: string
          public_location_label: string
          published_at: string
          resource_need_id: string
          text_match_kind: string
          title: string
        }[]
      }
      list_public_project_resource_needs: {
        Args: { p_project_id: string }
        Returns: {
          created_at: string
          details: string
          resource_need_id: string
          title: string
        }[]
      }
      list_public_proposals: {
        Args: {
          p_cursor_id?: string
          p_cursor_starts_at?: string
          p_limit?: number
          p_locality?: string
          p_skill_ids?: string[]
        }
        Returns: {
          administrative_area: string
          country_code: string
          derived_status: string
          ends_at: string
          event_timezone: string
          locality: string
          proposal_id: string
          public_location_label: string
          skills: Json
          starts_at: string
          summary: string
          title: string
        }[]
      }
      list_public_recurring_activities: {
        Args: {
          p_cursor_id?: string
          p_cursor_next_starts_at?: string
          p_limit?: number
          p_locality?: string
          p_reference_time: string
        }
        Returns: {
          administrative_area: string
          country_code: string
          event_timezone: string
          locality: string
          next_ends_at: string
          next_starts_at: string
          public_location_label: string
          recurring_activity_id: string
          summary: string
          title: string
          topic: string
        }[]
      }
      list_public_recurring_activity_occurrences: {
        Args: {
          p_from: string
          p_limit?: number
          p_recurring_activity_id: string
          p_until: string
        }
        Returns: {
          ends_at: string
          event_timezone: string
          local_starts_at: string
          recurring_activity_id: string
          starts_at: string
        }[]
      }
      list_public_resource_listings: {
        Args: {
          p_cursor_id?: string
          p_cursor_published_at?: string
          p_limit?: number
          p_listing_mode?: string
          p_locality?: string
          p_query?: string
        }
        Returns: {
          active_request_count: number
          administrative_area: string
          country_code: string
          description: string
          listing_id: string
          listing_mode: string
          locality: string
          public_location_label: string
          published_at: string
          title: string
        }[]
      }
      list_resource_exchange_agreement_events: {
        Args: { p_agreement_id: string; p_expected_profile_id: string }
        Returns: {
          actor_display_name: string
          actor_profile_id: string
          created_at: string
          event_id: string
          event_kind: string
          leg_kind: string
          terms_id: string
        }[]
      }
      list_resource_exchange_agreement_terms: {
        Args: { p_agreement_id: string; p_expected_profile_id: string }
        Returns: {
          created_at: string
          is_current: boolean
          is_pending: boolean
          listing_description_snapshot: string
          listing_title_snapshot: string
          owner_lend_ends_at: string
          owner_lend_starts_at: string
          owner_transfer_kind: string
          private_note: string
          proposed_by_profile_id: string
          requester_lend_ends_at: string
          requester_lend_starts_at: string
          requester_resource_description: string
          requester_transfer_kind: string
          terms_id: string
          version_number: number
        }[]
      }
      list_resource_listing_requests: {
        Args: { p_expected_owner_profile_id: string; p_listing_id: string }
        Returns: {
          coordination_closed_at: string
          coordination_closed_by_profile_id: string
          created_at: string
          request_id: string
          request_message: string
          requester_display_name: string
          requester_profile_id: string
          resolved_at: string
          resolved_by_profile_id: string
          status: string
        }[]
      }
      mark_all_notifications_read: {
        Args: { p_expected_profile_id: string }
        Returns: number
      }
      mark_notification_read: {
        Args: { p_expected_profile_id: string; p_notification_id: string }
        Returns: string
      }
      pause_recurring_activity: {
        Args: {
          p_expected_creator_profile_id: string
          p_recurring_activity_id: string
        }
        Returns: string
      }
      process_notification_outbox_batch: {
        Args: { p_limit?: number }
        Returns: {
          notifications_created: number
          notifications_suppressed: number
          processed_count: number
        }[]
      }
      process_push_outbox_batch: {
        Args: { p_limit?: number }
        Returns: {
          jobs_created: number
          jobs_suppressed: number
          processed_count: number
        }[]
      }
      process_resource_saved_search_matching_outbox_batch: {
        Args: { p_limit?: number }
        Returns: {
          matches_created: number
          matches_suppressed: number
          processed_count: number
        }[]
      }
      propose_resource_exchange_terms: {
        Args: {
          p_agreement_id: string
          p_expected_current_terms_id: string
          p_expected_pending_terms_id: string
          p_expected_profile_id: string
          p_owner_lend_ends_at: string
          p_owner_lend_starts_at: string
          p_owner_transfer_kind: string
          p_private_note: string
          p_requester_lend_ends_at: string
          p_requester_lend_starts_at: string
          p_requester_resource_description: string
          p_requester_transfer_kind: string
        }
        Returns: string
      }
      publish_proposal: {
        Args: { p_expected_creator_profile_id: string; p_proposal_id: string }
        Returns: string
      }
      publish_recurring_activity: {
        Args: {
          p_expected_creator_profile_id: string
          p_recurring_activity_id: string
        }
        Returns: string
      }
      publish_resource_listing: {
        Args: { p_expected_owner_profile_id: string; p_listing_id: string }
        Returns: string
      }
      record_resource_exchange_milestone: {
        Args: {
          p_agreement_id: string
          p_event_kind: string
          p_expected_profile_id: string
          p_expected_terms_id: string
          p_leg_kind: string
        }
        Returns: string
      }
      register_own_push_installation: {
        Args: {
          p_expected_profile_id: string
          p_installation_id: string
          p_platform: string
          p_provider_token: string
        }
        Returns: {
          installation_id: string
          last_registered_at: string
          platform: string
          provider: string
        }[]
      }
      reject_project_join_request: {
        Args: { p_expected_creator_profile_id: string; p_request_id: string }
        Returns: string
      }
      reject_resource_exchange_terms: {
        Args: {
          p_agreement_id: string
          p_expected_pending_terms_id: string
          p_expected_profile_id: string
        }
        Returns: string
      }
      reject_resource_listing_request: {
        Args: { p_expected_owner_profile_id: string; p_request_id: string }
        Returns: string
      }
      remove_project_member: {
        Args: { p_expected_creator_profile_id: string; p_membership_id: string }
        Returns: string
      }
      replace_project_membership_actual_contributions: {
        Args: {
          p_expected_creator_profile_id: string
          p_expected_resource_need_ids: string[]
          p_expected_skill_ids: string[]
          p_expected_substantial_effort: boolean
          p_membership_id: string
          p_resource_need_ids: string[]
          p_skill_ids: string[]
          p_substantial_effort: boolean
        }
        Returns: string
      }
      replace_project_membership_commitments: {
        Args: {
          p_expected_actor_profile_id: string
          p_expected_resource_need_ids: string[]
          p_expected_skill_ids: string[]
          p_membership_id: string
          p_resource_need_ids: string[]
          p_skill_ids: string[]
        }
        Returns: string
      }
      request_resource_listing: {
        Args: {
          p_expected_requester_profile_id: string
          p_listing_id: string
          p_message?: string
        }
        Returns: string
      }
      request_to_join_project: {
        Args: {
          p_expected_requester_profile_id: string
          p_project_id: string
          p_request_message?: string
          p_resource_need_ids?: string[]
          p_skill_ids?: string[]
        }
        Returns: string
      }
      resume_recurring_activity: {
        Args: {
          p_expected_creator_profile_id: string
          p_recurring_activity_id: string
        }
        Returns: string
      }
      send_project_chat_message: {
        Args: {
          p_body: string
          p_chat_id: string
          p_expected_profile_id: string
        }
        Returns: {
          body: string
          chat_id: string
          created_at: string
          message_id: string
          sender_profile_id: string
        }[]
      }
      send_resource_request_chat_message: {
        Args: {
          p_body: string
          p_chat_id: string
          p_expected_profile_id: string
        }
        Returns: {
          body: string
          chat_id: string
          created_at: string
          message_id: string
          sender_profile_id: string
        }[]
      }
      set_own_notification_preference: {
        Args: {
          p_category_slug: string
          p_expected_profile_id: string
          p_in_app_enabled: boolean
          p_push_enabled: boolean
        }
        Returns: undefined
      }
      set_own_profile_photo: {
        Args: {
          p_audience: string
          p_expected_profile_id: string
          p_object_path: string
        }
        Returns: {
          audience: string
          current_object_path: string
          previous_object_path: string
          updated_at: string
        }[]
      }
      set_own_profile_photo_audience: {
        Args: { p_audience: string; p_expected_profile_id: string }
        Returns: {
          audience: string
          object_path: string
          profile_id: string
          updated_at: string
        }[]
      }
      set_project_requirement_manual_coverage: {
        Args: {
          p_expected_creator_profile_id: string
          p_is_covered: boolean
          p_project_id: string
          p_requirement_id: string
          p_requirement_kind: string
        }
        Returns: string
      }
      submit_moderation_report: {
        Args: {
          p_category: string
          p_client_submission_id: string
          p_context_id?: string
          p_context_kind?: string
          p_expected_reporter_profile_id: string
          p_explanation: string
          p_target_id: string
          p_target_kind: string
        }
        Returns: {
          case_id: string
          created_at: string
          report_id: string
          state: string
        }[]
      }
      transition_moderation_case: {
        Args: {
          p_case_id: string
          p_expected_staff_profile_id: string
          p_expected_state_version: number
          p_target_state: string
        }
        Returns: {
          state: string
          state_version: number
          updated_at: string
        }[]
      }
      unregister_own_push_installation: {
        Args: { p_expected_profile_id: string; p_installation_id: string }
        Returns: boolean
      }
      update_own_profile: {
        Args: {
          p_bio: string
          p_bio_audience: string
          p_display_name: string
          p_display_name_audience: string
          p_expected_profile_id: string
          p_skill_ids: string[]
          p_skills_audience: string
        }
        Returns: undefined
      }
      update_own_proposal: {
        Args: {
          p_administrative_area: string
          p_country_code: string
          p_description: string
          p_ends_at: string
          p_event_timezone: string
          p_exact_location_visibility: string
          p_exact_meeting_text: string
          p_expected_creator_profile_id: string
          p_locality: string
          p_proposal_id: string
          p_public_location_label: string
          p_skill_ids: string[]
          p_skill_importances: string[]
          p_starts_at: string
          p_summary: string
          p_title: string
        }
        Returns: string
      }
      update_own_recurring_activity: {
        Args: {
          p_administrative_area: string
          p_country_code: string
          p_day_of_month: number
          p_description: string
          p_duration_minutes: number
          p_effective_from: string
          p_event_timezone: string
          p_exact_location_visibility: string
          p_exact_meeting_text: string
          p_expected_creator_profile_id: string
          p_local_start_time: string
          p_locality: string
          p_public_location_label: string
          p_recurrence_type: string
          p_recurring_activity_id: string
          p_summary: string
          p_title: string
          p_topic: string
          p_weekday: number
        }
        Returns: string
      }
      update_own_resource_listing: {
        Args: {
          p_administrative_area: string
          p_country_code: string
          p_description: string
          p_expected_owner_profile_id: string
          p_listing_id: string
          p_listing_mode: string
          p_locality: string
          p_public_location_label: string
          p_title: string
        }
        Returns: string
      }
      update_project_resource_need: {
        Args: {
          p_details?: string
          p_expected_creator_profile_id: string
          p_resource_need_id: string
          p_title: string
        }
        Returns: string
      }
      update_resource_saved_search: {
        Args: {
          p_expected_profile_id: string
          p_listing_mode: string
          p_locality: string
          p_query: string
          p_saved_search_id: string
        }
        Returns: string
      }
      withdraw_project_join_request: {
        Args: { p_expected_requester_profile_id: string; p_request_id: string }
        Returns: string
      }
      withdraw_resource_exchange_terms: {
        Args: {
          p_agreement_id: string
          p_expected_pending_terms_id: string
          p_expected_profile_id: string
        }
        Returns: string
      }
      withdraw_resource_listing_request: {
        Args: { p_expected_requester_profile_id: string; p_request_id: string }
        Returns: string
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
