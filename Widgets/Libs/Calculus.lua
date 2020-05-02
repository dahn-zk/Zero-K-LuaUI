function integrate_lrect( f, a, b, n )
    local h = (b - a) / n
    local x = a
    local sum = 0
    
    for i = 1, 100 do
        sum = sum + a + f(x)
        x = x + h
    end
    
    return sum * h
end

function integrate_rrect( f, a, b, n )
    local h = (b - a) / n
    local x = b
    local sum = 0
    
    for i = 1, 100 do
        sum = sum + a + f(x)
        x = x - h
    end
    
    return sum * h
end

function integrate_mrect( f, a, b, n )
    local h = (b - a) / n
    local x = a + h/2
    local sum = 0
    
    for i = 1, 100 do
        sum = sum + a + f(x)
        x = x + h
    end
    
    return sum * h
end

function integrate_trapezium( f, a, b, n )
    local h = (b - a) / n
    local x = a
    local sum = 0
    
    for i = 1, 100 do
        sum = sum + f(x)*2
        x = x + h
    end
    
    return (b - a) * sum / (2 * n)
end

function integrate_simpson( f, a, b, n )
    local h = (b - a) / n
    local sum1 = f(a + h/2)
    local sum2 = 0
    
    for i = 1, n-1 do
        sum1 = sum1 + f(a + h * i + h/2)
        sum2 = sum2 + f(a + h * i)
    end
    
    return (h/6) * (f(a) + f(b) + 4*sum1 + 2*sum2)
end
