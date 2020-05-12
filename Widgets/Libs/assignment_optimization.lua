local huge = math.huge

--- Hungarian algorithm
--- Adapted from CustomFormations2 widget
function assign ( cost_matrix )
    local n = #cost_matrix
    
    local col_cover  = {}
    local row_cover  = {}
    local stars_col  = {}
    local primes_col = {}
    for i = 1, n do
        row_cover[i]  = false
        col_cover[i]  = false
        stars_col[i]  = false
        primes_col[i] = false
    end
    
    -- Subtract minimum from rows
    for i = 1, n do
        local aRow = cost_matrix[i]
        local minVal = aRow[1]
        for j = 2, n do
            if aRow[j] < minVal then
                minVal = aRow[j]
            end
        end
        for j = 1, n do
            aRow[j] = aRow[j] - minVal
        end
    end
    
    -- Subtract minimum from columns
    for j = 1, n do
        local minVal = cost_matrix[1][j]
        for i = 2, n do
            if cost_matrix[i][j] < minVal then
                minVal = cost_matrix[i][j]
            end
        end
        for i = 1, n do
            cost_matrix[i][j] = cost_matrix[i][j] - minVal
        end
    end
    
    -- Star zeroes
    for i = 1, n do
        local aRow = cost_matrix[i]
        for j = 1, n do
            if (aRow[j] == 0) and not col_cover[j] then
                col_cover[j] = true
                stars_col[i] = j
                break
            end
        end
    end
    
    -- Start solving system
    while true do
        -- Are we done ?
        local done = true
        for i = 1, n do
            if not col_cover[i] then
                done = false
                break
            end
        end
        
        if done then
            local pairings = {}
            for i = 1, n do
                pairings[i] = stars_col[i]
            end
            return pairings
        end
        
        -- Not done
        local r, c = step_prime_zeroes(cost_matrix, col_cover, row_cover, n, stars_col, primes_col)
        step_five_star(col_cover, row_cover, r, c, n, stars_col, primes_col)
    end
end

function do_prime (array, colcover, rowcover, n, starscol, r, c, rmax, primescol)
    primescol[r] = c
    
    local starCol = starscol[r]
    if starCol then
        
        rowcover[r] = true
        colcover[starCol] = false
        
        for i = 1, rmax do
            if not rowcover[i] and (array[i][starCol] == 0) then
                local rr, cc = do_prime(array, colcover, rowcover, n, starscol, i, starCol, rmax, primescol)
                if rr then
                    return rr, cc
                end
            end
        end
        
        return
    else
        return r, c
    end
end

function step_prime_zeroes (array, colcover, rowcover, n, starscol, primescol)
    while true do
        
        -- Find uncovered zeros and prime them
        for i = 1, n do
            if not rowcover[i] then
                local aRow = array[i]
                for j = 1, n do
                    if (aRow[j] == 0) and not colcover[j] then
                        local i, j = do_prime(array, colcover, rowcover, n, starscol, i, j, i - 1, primescol)
                        if i then
                            return i, j
                        end
                        break -- this row is covered
                    end
                end
            end
        end
        
        -- Find minimum uncovered
        local minVal = huge
        for i = 1, n do
            if not rowcover[i] then
                local aRow = array[i]
                for j = 1, n do
                    if (aRow[j] < minVal) and not colcover[j] then
                        minVal = aRow[j]
                    end
                end
            end
        end
        
        -- There is the potential for minVal to be 0, very very rarely though. (Checking for it costs more than the +/- 0's)
        
        -- Covered rows = +
        -- Uncovered cols = -
        for i = 1, n do
            local aRow = array[i]
            if rowcover[i] then
                for j = 1, n do
                    if colcover[j] then
                        aRow[j] = aRow[j] + minVal
                    end
                end
            else
                for j = 1, n do
                    if not colcover[j] then
                        aRow[j] = aRow[j] - minVal
                    end
                end
            end
        end
    end
end

function step_five_star(colcover, rowcover, row, col, n, starscol, primescol)
    -- Star the initial prime
    primescol[row] = false
    starscol[row] = col
    local ignoreRow = row -- Ignore the star on this row when looking for next
    
    repeat
        local noFind = true
        
        for i = 1, n do
            
            if (starscol[i] == col) and (i ~= ignoreRow) then
                
                noFind = false
                
                -- Unstar the star
                -- Turn the prime on the same row into a star (And ignore this row (aka star) when searching for next star)
                
                local pcol = primescol[i]
                primescol[i] = false
                starscol[i] = pcol
                ignoreRow = i
                col = pcol
                
                break
            end
        end
    until noFind
    
    for i = 1, n do
        rowcover[i] = false
        colcover[i] = false
        primescol[i] = false
    end
    
    for i = 1, n do
        local scol = starscol[i]
        if scol then
            colcover[scol] = true
        end
    end
end
