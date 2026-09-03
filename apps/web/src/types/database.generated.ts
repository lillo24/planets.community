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
      publish_proposal: {
        Args: { p_expected_creator_profile_id: string; p_proposal_id: string }
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
