export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.15";
  };
  public: {
    Tables: {
      bean_photos: {
        Row: {
          bean_id: string | null;
          created_at: string;
          deleted_at: string | null;
          id: string;
          order: number;
          remote_path: string | null;
          updated_at: string;
        };
        Insert: {
          bean_id?: string | null;
          created_at?: string;
          deleted_at?: string | null;
          id: string;
          order?: number;
          remote_path?: string | null;
          updated_at?: string;
        };
        Update: {
          bean_id?: string | null;
          created_at?: string;
          deleted_at?: string | null;
          id?: string;
          order?: number;
          remote_path?: string | null;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "bean_photos_bean_id_fkey";
            columns: ["bean_id"];
            isOneToOne: false;
            referencedRelation: "beans";
            referencedColumns: ["id"];
          },
        ];
      };
      beans: {
        Row: {
          country: string | null;
          created_at: string;
          deleted_at: string | null;
          farm: string | null;
          finished_at: string | null;
          id: string;
          my_flavor_tags: string[];
          name: string;
          pending_next_espresso: Json | null;
          pending_next_pourover: Json | null;
          process: string | null;
          region: string | null;
          roast_date: string | null;
          roast_level: string | null;
          roaster_name: string | null;
          roaster_notes: string | null;
          price_sgd: number | null;
          bag_size_grams: number | null;
          updated_at: string;
          varietal: string | null;
        };
        Insert: {
          country?: string | null;
          created_at?: string;
          deleted_at?: string | null;
          farm?: string | null;
          finished_at?: string | null;
          id: string;
          my_flavor_tags?: string[];
          name?: string;
          pending_next_espresso?: Json | null;
          pending_next_pourover?: Json | null;
          process?: string | null;
          region?: string | null;
          roast_date?: string | null;
          roast_level?: string | null;
          roaster_name?: string | null;
          roaster_notes?: string | null;
          price_sgd?: number | null;
          bag_size_grams?: number | null;
          updated_at?: string;
          varietal?: string | null;
        };
        Update: {
          country?: string | null;
          created_at?: string;
          deleted_at?: string | null;
          farm?: string | null;
          finished_at?: string | null;
          id?: string;
          my_flavor_tags?: string[];
          name?: string;
          pending_next_espresso?: Json | null;
          pending_next_pourover?: Json | null;
          process?: string | null;
          region?: string | null;
          roast_date?: string | null;
          roast_level?: string | null;
          roaster_name?: string | null;
          roaster_notes?: string | null;
          price_sgd?: number | null;
          bag_size_grams?: number | null;
          updated_at?: string;
          varietal?: string | null;
        };
        Relationships: [];
      };
      brews: {
        Row: {
          bean_id: string | null;
          brewed_at: string;
          brewers: string[];
          created_at: string;
          deleted_at: string | null;
          id: string;
          method_raw: string;
          next_recipe_draft: Json | null;
          photo_path: string | null;
          recipe: Json;
          taste: Json;
          updated_at: string;
        };
        Insert: {
          bean_id?: string | null;
          brewed_at?: string;
          brewers?: string[];
          created_at?: string;
          deleted_at?: string | null;
          id: string;
          method_raw?: string;
          next_recipe_draft?: Json | null;
          photo_path?: string | null;
          recipe?: Json;
          taste?: Json;
          updated_at?: string;
        };
        Update: {
          bean_id?: string | null;
          brewed_at?: string;
          brewers?: string[];
          created_at?: string;
          deleted_at?: string | null;
          id?: string;
          method_raw?: string;
          next_recipe_draft?: Json | null;
          photo_path?: string | null;
          recipe?: Json;
          taste?: Json;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "brews_bean_id_fkey";
            columns: ["bean_id"];
            isOneToOne: false;
            referencedRelation: "beans";
            referencedColumns: ["id"];
          },
        ];
      };
      grinders: {
        Row: {
          created_at: string;
          deleted_at: string | null;
          id: string;
          name: string;
          stepless: boolean;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          deleted_at?: string | null;
          id: string;
          name?: string;
          stepless?: boolean;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          deleted_at?: string | null;
          id?: string;
          name?: string;
          stepless?: boolean;
          updated_at?: string;
        };
        Relationships: [];
      };
      lexicon_terms: {
        Row: {
          created_at: string;
          deleted_at: string | null;
          field_raw: string;
          id: string;
          term: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          deleted_at?: string | null;
          field_raw?: string;
          id: string;
          term?: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          deleted_at?: string | null;
          field_raw?: string;
          id?: string;
          term?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      [_ in never]: never;
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">;

type DefaultSchema = DatabaseWithoutInternals[Extract<
  keyof Database,
  "public"
>];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R;
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R;
      }
      ? R
      : never
    : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I;
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I;
      }
      ? I
      : never
    : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U;
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U;
      }
      ? U
      : never
    : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    keyof DefaultSchema["Enums"] | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never;

export const Constants = {
  public: {
    Enums: {},
  },
} as const;
