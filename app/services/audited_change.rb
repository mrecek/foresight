class AuditedChange
  class << self
    def create(record, request)
      record.class.transaction do
        record.save!
        AuditLog.log_create(record, request)
        record
      end
    end

    def update(record, attributes, request)
      record.class.transaction do
        record.update!(attributes)
        AuditLog.log_update(record, request)
        record
      end
    end

    def destroy(record, request)
      record.class.transaction do
        AuditLog.log_delete(record, request)
        record.destroy!
      end
    end
  end
end
