#version 330

layout (triangles) in;
layout (triangle_strip, max_vertices = 5) out;

uniform float scale;
uniform float aspect_ratio;
uniform float anti_alias_width;
uniform vec3 frame_center;

in vec3 bp[3];
in vec4 v_color[3];
in float v_fill_all[3];

out vec4 color;
out float fill_all;
out float uv_anti_alias_width;
// uv space is where b0 = (0, 0), b1 = (1, 0), and transform is orthogonal
out vec2 uv_coords;
out vec2 uv_b2;

out float bezier_degree;

// To my knowledge, there is no notion of #include for shaders,
// so to share functionality between this and others, the caller
// in manim replaces this line with the contents of named file
#INSERT quadratic_bezier_geometry_functions.glsl
#INSERT scale_and_shift_point_for_frame.glsl

void emit_simple_triangle(){
    for(int i = 0; i < 3; i++){
        color = v_color[i];
        gl_Position = vec4(
            scale_and_shift_point_for_frame(bp[i]),
            1.0
        );
        EmitVertex();
    }
    EndPrimitive();
}


void emit_pentagon(vec2 bp0, vec2 bp1, vec2 bp2){
    // Tangent vectors
    vec2 t01 = normalize(bp1 - bp0);
    vec2 t12 = normalize(bp2 - bp1);
    // Normal vectors
    // Rotate tangent vector 90-degrees clockwise
    vec2 n01 = vec2(t01.y, -t01.x);
    vec2 n12 = vec2(t12.y, -t12.x);

    float c_orient = sign(cross(t01, t12));
    bool fill_in = (c_orient > 0);

    float aaw = anti_alias_width;
    vec2 nudge1 = fill_in ? 0.5 * aaw * (n01 + n12) : vec2(0);
    vec2 corners[5] = vec2[5](
        bp0 + aaw * n01,
        bp0,
        bp1 + nudge1,
        bp2,
        bp2 + aaw * n12
    );

    int coords_index_map[5] = int[5](0, 1, 2, 3, 4);
    if(!fill_in) coords_index_map = int[5](1, 0, 2, 4, 3);
        
    mat3 xy_to_uv = get_xy_to_uv(bp0, bp1);
    uv_b2 = (xy_to_uv * vec3(bp2, 1)).xy;
    uv_anti_alias_width = anti_alias_width / length(bp1 - bp0);

    int nearest_bp_index_map[5] = int[5](0, 0, 1, 2, 2);
    for(int i = 0; i < 5; i++){
        vec2 corner = corners[coords_index_map[i]];
        float z = bp[nearest_bp_index_map[i]].z;
        uv_coords = (xy_to_uv * vec3(corner, 1)).xy;
        // I haven't a clue why an index map doesn't work just
        // as well here, but for some reason it doesn't.
        if(i < 2)       color = v_color[0];
        else if(i == 2) color = v_color[1];
        else            color = v_color[2];
        gl_Position = vec4(
            scale_and_shift_point_for_frame(vec3(corner, z)),
            1.0
        );
        EmitVertex();
    }
    EndPrimitive();
}


void main(){
    fill_all = v_fill_all[0];

    if(fill_all == 1){
        emit_simple_triangle();
        return;
    }

    vec2 new_bp[3];
    int n = get_reduced_control_points(bp[0].xy, bp[1].xy, bp[2].xy, new_bp);
    bezier_degree = float(n);
    vec2 bp0, bp1, bp2;
    if(n == 0){
        return;  // Don't emit any vertices
    }
    else if(n == 1){
        bp0 = new_bp[0];
        bp2 = new_bp[1];
        bp1 = 0.5 * (bp0 + bp2);
    }else{
        bp0 = new_bp[0];
        bp1 = new_bp[1];
        bp2 = new_bp[2];
    }

    emit_pentagon(bp0, bp1, bp2);
}
