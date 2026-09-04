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
      cancel_proposal: {
        Args: { p_expected_creator_profile_id: string; p_proposal_id: string }
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
      end_recurring_activity: {
        Args: {
          p_expected_creator_profile_id: string
          p_recurring_activity_id: string
        }
        Returns: string
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
      pause_recurring_activity: {
        Args: {
          p_expected_creator_profile_id: string
          p_recurring_activity_id: string
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
      resume_recurring_activity: {
        Args: {
          p_expected_creator_profile_id: string
          p_recurring_activity_id: string
        }
        Returns: string
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
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
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
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
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
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
