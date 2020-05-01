atan = math.atan

function vector_atan(a, b)
    return atan((a[1] - b[1]) / (a[3] - b[3]))
end
