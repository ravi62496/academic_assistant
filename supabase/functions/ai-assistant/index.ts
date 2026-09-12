import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const rawGeminiKey = Deno.env.get("GEMINI_API_KEY") || "";
    const rawNvidiaKey = Deno.env.get("NVIDIA_API_KEY") || "";

    const geminiKey = rawGeminiKey.replace(/^bearer\s+/i, "").trim();
    const nvidiaKey = rawNvidiaKey.replace(/^bearer\s+/i, "").trim();

    if (!geminiKey && !nvidiaKey) {
      return new Response(
        JSON.stringify({
          error: "Neither GEMINI_API_KEY nor NVIDIA_API_KEY secret is set in Supabase environment.",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const { message, image_base64, courses, classes, history } = await req.json();
    const isVision = Boolean(image_base64 && image_base64.trim().length > 0);

    // 1. Build system prompt with live context
    const systemPrompt = `You are an AI Assistant for an academic scheduling app. Your task is to assist students with managing their courses, class schedules, timetable image imports, and schedule overrides.

CRITICAL INSTRUCTIONS:
1. Always reference real IDs from the CURRENT USER CONTEXT provided below when modifying or deleting courses/classes/overrides. DO NOT invent UUIDs.
2. If the user asks to add a class for a course that does not exist yet, call 'add_course' or include course details in 'import_schedule_from_image'.
3. Day of week is an integer: 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday, 7=Sunday.
4. Format times strictly as "HH:mm" in 24-hour format (e.g. "09:00", "14:30").
5. Dates for overrides must be in strictly "YYYY-MM-DD" format.
6. When an image of a schedule or timetable is attached, carefully extract ALL courses and classes from it and call the 'import_schedule_from_image' tool with the extracted entries list.
7. Be concise and friendly in your textual response.

CURRENT USER CONTEXT:
Existing Courses:
${JSON.stringify(courses || [], null, 2)}

Existing Class Schedules:
${JSON.stringify(classes || [], null, 2)}
`;

    // 2. Define tool definitions
    const tools = [
      {
        type: "function",
        function: {
          name: "add_course",
          description: "Add a new academic course.",
          parameters: {
            type: "object",
            properties: {
              name: { type: "string", description: "Course name, e.g. Data Structures" },
              code: { type: "string", description: "Course code, e.g. CS101" },
              professor: { type: "string", description: "Professor or instructor name" }
            },
            required: ["name"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "update_course",
          description: "Update details of an existing course.",
          parameters: {
            type: "object",
            properties: {
              course_id: { type: "string", description: "ID of the existing course" },
              name: { type: "string", description: "Updated course name" },
              code: { type: "string", description: "Updated course code" },
              professor: { type: "string", description: "Updated professor name" }
            },
            required: ["course_id"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "delete_course",
          description: "Delete a course by ID.",
          parameters: {
            type: "object",
            properties: {
              course_id: { type: "string", description: "ID of the course to delete" }
            },
            required: ["course_id"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "add_class",
          description: "Add a new recurring class schedule slot.",
          parameters: {
            type: "object",
            properties: {
              course_id: { type: "string", description: "ID of the existing course" },
              day_of_week: { type: "integer", description: "1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday, 7=Sunday" },
              start_time: { type: "string", description: "Start time in HH:mm 24h format" },
              end_time: { type: "string", description: "End time in HH:mm 24h format" },
              room: { type: "string", description: "Classroom or room number" }
            },
            required: ["course_id", "day_of_week", "start_time", "end_time"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "update_class",
          description: "Update an existing class schedule slot.",
          parameters: {
            type: "object",
            properties: {
              class_id: { type: "string", description: "ID of the class schedule to update" },
              course_id: { type: "string", description: "Course ID if changing course" },
              day_of_week: { type: "integer", description: "1=Monday..7=Sunday" },
              start_time: { type: "string", description: "Start time in HH:mm 24h format" },
              end_time: { type: "string", description: "End time in HH:mm 24h format" },
              room: { type: "string", description: "Classroom or room number" }
            },
            required: ["class_id"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "delete_class",
          description: "Delete a recurring class schedule slot.",
          parameters: {
            type: "object",
            properties: {
              class_id: { type: "string", description: "ID of the class schedule to delete" }
            },
            required: ["class_id"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "add_override",
          description: "Cancel or reschedule a specific occurrence of a class on a specific date.",
          parameters: {
            type: "object",
            properties: {
              class_id: { type: "string", description: "ID of the class schedule to override" },
              date: { type: "string", description: "Date of override in YYYY-MM-DD format" },
              type: { type: "string", enum: ["cancelled", "rescheduled"], description: "Override type" },
              new_start_time: { type: "string", description: "New start time in HH:mm format if rescheduled" },
              new_end_time: { type: "string", description: "New end time in HH:mm format if rescheduled" },
              new_room: { type: "string", description: "New room if rescheduled" },
              new_day_of_week: { type: "integer", description: "New day of week (1..7) if rescheduled" }
            },
            required: ["class_id", "date", "type"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "import_schedule_from_image",
          description: "Import multiple class schedule entries extracted from a timetable image/photo.",
          parameters: {
            type: "object",
            properties: {
              entries: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    course_name: { type: "string", description: "Course name" },
                    course_code: { type: "string", description: "Course code if available" },
                    professor: { type: "string", description: "Professor name if available" },
                    day_of_week: { type: "integer", description: "1=Monday..7=Sunday" },
                    start_time: { type: "string", description: "Start time in HH:mm format" },
                    end_time: { type: "string", description: "End time in HH:mm format" },
                    room: { type: "string", description: "Room/location if available" }
                  },
                  required: ["course_name", "day_of_week", "start_time", "end_time"]
                }
              }
            },
            required: ["entries"]
          }
        }
      }
    ];

    // 3. Assemble messages array
    const messages: any[] = [
      { role: "system", content: systemPrompt }
    ];

    if (Array.isArray(history)) {
      messages.push(...history);
    }

    if (isVision) {
      const formattedImageUrl = image_base64.startsWith("data:")
        ? image_base64
        : `data:image/jpeg;base64,${image_base64}`;

      const userContent: any[] = [];
      if (message && message.trim().length > 0) {
        userContent.push({ type: "text", text: message.trim() });
      } else {
        userContent.push({
          type: "text",
          text: "Please analyze this timetable image and extract all scheduled classes."
        });
      }
      userContent.push({
        type: "image_url",
        image_url: { url: formattedImageUrl }
      });

      messages.push({ role: "user", content: userContent });
    } else if (message && message.trim().length > 0) {
      messages.push({ role: "user", content: message.trim() });
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 55000);

    let apiUrl: string;
    let apiKeyToUse: string;
    let modelName: string;

    if (geminiKey) {
      apiUrl = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions";
      apiKeyToUse = geminiKey;
      modelName = "gemini-3.6-flash";
    } else {
      apiUrl = "https://integrate.api.nvidia.com/v1/chat/completions";
      apiKeyToUse = nvidiaKey;
      modelName = isVision ? "meta/llama-3.2-11b-vision-instruct" : "meta/llama-3.3-70b-instruct";
    }

    let apiRes: Response;
    try {
      apiRes = await fetch(apiUrl, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKeyToUse}`,
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        signal: controller.signal,
        body: JSON.stringify({
          model: modelName,
          messages: messages,
          tools: tools,
          tool_choice: "auto",
          temperature: 0.2,
          max_tokens: 2048,
          extra_body: {
            google: {
              thinking_config: {
                thinking_level: "low",
              },
            },
          },
        }),
      });
    } finally {
      clearTimeout(timeoutId);
    }

    if (!apiRes.ok) {
      const errText = await apiRes.text();
      return new Response(
        JSON.stringify({ error: `AI API error (${apiRes.status}): ${errText}` }),
        {
          status: apiRes.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const data = await apiRes.json();

    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "Unknown error occurred" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
