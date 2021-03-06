local spec  = require 'spec.spec'

describe("404 alert", function()
  local alert
  before_each(function()
    alert = spec.middleware('404-alert/404_alert.lua')
  end)

  describe("when the status is not 404", function()
    it("does nothing", function()
      local request         = spec.request({method = 'GET', uri = '/'})
      local next_middleware = spec.next_middleware(function()
        assert.contains(request, {method = 'GET', uri = '/'})
        return {status = 200, body = 'ok'}
      end)

      local response = alert(request, next_middleware)

      assert.spy(next_middleware).was_called()
      assert.contains(response, {status = 200, body = 'ok'})

      assert.equal(#spec.sent.emails, 0)
      assert.equal(#spec.bucket.middleware.get_keys(), 0)
    end)
  end)

  describe("when the status is 404", function()
    describe("when it happens once", function()
      it("sends an email and marks the middleware bucket", function()
        local request         = spec.request({uri = '/'})
        local next_middleware = spec.next_middleware(function()
          assert.contains(request, {method = 'GET', uri = '/'})
          return {status = 404, body = 'not ok'}
        end)

        local response = alert(request, next_middleware)

        assert.spy(next_middleware).was_called()
        assert.contains(response, {status = 404, body = 'not ok'})

        assert.truthy(spec.bucket.middleware.get('last_mail'))

        assert.equal(#spec.sent.emails, 1)

        local last_email = spec.sent.emails.last
        assert.equal('YOUR-MAIL-HERE@gmail.com', last_email.to)
        assert.equal('A 404 has ocurred', last_email.subject)
        assert.equal('a 404 error happened in http://localhost/ see full trace: <trace_link>', last_email.message)
      end)
    end)

    describe("when the 404 happens more than once", function()
      describe("and the time between errors is smaller than the threshold", function()
        it("only sends one email", function()
          local request         = spec.request({method = 'GET', uri = '/'})
          local next_middleware = spec.next_middleware(function()
            assert.contains(request, {method = 'GET', uri = '/'})
            return {status = 404, body = 'not ok'}
          end)

          alert(request, next_middleware)
          spec.advance_time(10)
          alert(request, next_middleware) -- twice
          assert.spy(next_middleware).was_called(2)


          assert.equal(1, #spec.sent.emails)
        end)

        describe("and the time between errors is greater than the threshold", function()
          it("sends several emails", function()
            local request         = spec.request({method = 'GET', uri = '/'})
            local next_middleware = spec.next_middleware(function()
              assert.contains(request, {method = 'GET', uri = '/'})
              return {status = 404, body = 'not ok'}
            end)

            alert(request, next_middleware)
            spec.advance_time(5 * 60 + 1)
            alert(request, next_middleware)
            assert.spy(next_middleware).was_called(2)


            assert.equal(2, #spec.sent.emails)
          end)
        end)
      end)


    end)




  end)
end)
